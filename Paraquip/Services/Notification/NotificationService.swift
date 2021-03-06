//
//  NotificationService.swift
//  Paraquip
//
//  Created by Simon Seyer on 20.05.21.
//

import Foundation
import Combine
import OSLog
import CoreData

struct NotificationState {

    var isEnabled: Bool
    var wasRequestRejected: Bool
    var configuration: [NotificationConfig]
}

enum NavigationState: Equatable {
    case none
    case notificationSettings
    case equipment(Equipment)
}

fileprivate extension NotificationState {
    static var `default`: NotificationState {
        NotificationState(
            isEnabled: false,
            wasRequestRejected: false,
            configuration: [
                NotificationConfig(unit: .months, multiplier: 1)
            ]
        )
    }
}

struct NotificationConfig: Identifiable, Hashable {

    enum Unit: Int {
        case days, months
    }

    let id = UUID()
    var unit: Unit
    var multiplier: Int
}

class NotificationService: ObservableObject {

    private let persistence: NotificationPersistence
    private let notifications: NotificationPlugin
    private let managedObjectContext: NSManagedObjectContext
    private let logger = Logger(category: "NotificationsStore")

    private var subscriptions = Set<AnyCancellable>()

    private static let notificationHour = 9
    private static let notificationSchedulingDebounce: TimeInterval = 2

    @Published private(set) var state: NotificationState {
        didSet {
            persistence.save(notificationState: state.toPersistence())
            scheduleNotifications(configuration: state.configuration)
        }
    }
    @Published private(set) var navigationState = NavigationState.none

    init(managedObjectContext: NSManagedObjectContext, persistence: NotificationPersistence = .init(), notifications: NotificationPlugin = AppleNotificationPlugin()) {
        self.managedObjectContext = managedObjectContext
        self.persistence = persistence
        self.notifications = notifications
        self.state = persistence.load()?.toModel() ?? .default

        setupNotificationHandler()
        setupNotificationScheduling()
    }

    init(state: NotificationState, managedObjectContext: NSManagedObjectContext, persistence: NotificationPersistence = .init(), notifications: NotificationPlugin = AppleNotificationPlugin()) {
        self.managedObjectContext = managedObjectContext
        self.persistence = persistence
        self.notifications = notifications
        self.state = state

        setupNotificationHandler()
        setupNotificationScheduling()
        scheduleNotifications(configuration: state.configuration)
    }

    private func setupNotificationHandler() {
        notifications
            .authorizationStatus
            .sink { [weak self] status in
                self?.logger.info("Authorization status updated: \(status)")
                if status == .denied {
                    self?.state.isEnabled = false
                    self?.state.wasRequestRejected = true
                } else {
                    self?.state.wasRequestRejected = false
                }
            }
            .store(in: &subscriptions)

        notifications
            .openSettingsReceived
            .sink { [weak self] in
                self?.logger.info("Handling open settings")
                self?.navigationState = .notificationSettings
            }
            .store(in: &subscriptions)

        notifications
            .notificationReceived
            .map { $0.equipmentId }
            .sink { [weak self] equipment in
                self?.logger.info("Handling notification for equipment: \(equipment)")
                
                let fetchRequest = Equipment.fetchRequest()
                fetchRequest.predicate = .init(format: "id == %@", equipment as CVarArg)
                fetchRequest.fetchLimit = 1
                let equipmentModel = try? self?.managedObjectContext.fetch(fetchRequest).first
                
                if let equipmentModel = equipmentModel {
                    self?.navigationState = .equipment(equipmentModel)
                } else {
                    self?.logger.error("Unable to fetch equipment: \(equipment)")
                }
            }
            .store(in: &subscriptions)
    }

    private func setupNotificationScheduling() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(managedObjectContextDidSave), name: NSNotification.Name.NSManagedObjectContextDidSave, object: managedObjectContext)
    }

    @objc private func managedObjectContextDidSave() {
        scheduleNotifications(configuration: state.configuration)
    }

    private func scheduleNotifications(configuration: [NotificationConfig]) {
        let fetchRequest = Equipment.fetchRequest()
        let equipment: [Equipment] = (try? managedObjectContext.fetch(fetchRequest)) ?? []
        scheduleNotifications(for: equipment, configuration: configuration)
    }

    func enable(completion: @escaping () -> Void)  {
        notifications.requestAuthorization() {[weak self, logger] success, error in
            if let error = error {
                logger.error("Failed to enable notifications: \(error.localizedDescription)")
            }

            DispatchQueue.main.async {
                if success {
                    self?.state.isEnabled = true
                } else {
                    self?.state.wasRequestRejected = true
                }

                completion()
            }
        }
    }

    func disable() {
        state.isEnabled = false
    }

    func addNotificationConfig() {
        state.configuration.append(NotificationConfig(unit: .months, multiplier: 1))
    }

    func removeNotificationConfigs(atOffsets indexSet: IndexSet) {
        state.configuration.remove(atOffsets: indexSet)
    }

    func update(notificationConfig: NotificationConfig) {
        guard let index = state.configuration.firstIndex(where: { $0.id == notificationConfig.id }) else {
            return
        }
        state.configuration[index] = notificationConfig
    }

    func resetNavigationState() {
        navigationState = .none
    }

    private func scheduleNotifications(for equipment: [Equipment], configuration: [NotificationConfig]) {
        notifications.reset()

        guard state.isEnabled else {
            return
        }

        logger.info("Updating notifications")

        for equipment in equipment {
            for notificationConfig in configuration {
                scheduleNotification(for: equipment, config: notificationConfig)
            }
        }

        updateBadge(for: equipment)
    }

    private func scheduleNotification(for equipment: Equipment, config: NotificationConfig) {
        guard let nextCheck = equipment.nextCheck else {
            logger.info("Skipping notifications for equipment since check is off: \(equipment.id!)")
            return
        }

        let date = Calendar.current.date(byAdding: config.dateComponents,
                                         to: nextCheck.settingTimeTo(hour: Self.notificationHour))!

        guard date > Date.paraquipNow else {
            logger.info("Ignoring notification config because it lies in the past: \(config)")
            return
        }

        let body = LocalizedNotificationString(
            key: config.bodyLocalizationKey,
            arguments: [equipment.brandName, equipment.equipmentName, String(config.multiplier)]
        )

        let notification = Notification(
            equipmentId: equipment.id!,
            notificationConfigId: config.id,
            title: "notification_check_due_title",
            body: body,
            date: date
        )

        logger.info("Adding: \(notification)")
        notifications.add(notification: notification) {[logger] error in
            if let error = error {
                logger.error("Failed to add notification \(notification.id): \(error.description)")
            }
        }
    }

    private func updateBadge(for equipment: [Equipment]) {
        let badgeCount = equipment.filter {
            if case .now = $0.checkUrgency {
                return true
            }
            return false
        }.count

        notifications.setBadge(count: badgeCount)
        logger.info("Set badge count: \(badgeCount)")
    }
}

extension NotificationConfig: CustomStringConvertible {
    var description: String {
        "NotificationConfig(\(multiplier) \(unit))"
    }
}

fileprivate extension NotificationConfig {
    var bodyLocalizationKey: String {
        switch unit {
        case .days:
            switch multiplier {
            case 0:
                return "notification_check_due_days_body_zero"
            case 1:
                return "notification_check_due_days_body_one"
            case 2:
                return "notification_check_due_days_body_two"
            default:
                return "notification_check_due_days_body_other"
            }
        case .months:
            switch multiplier {
            case 0:
                return "notification_check_due_months_body_zero"
            case 1:
                return "notification_check_due_months_body_one"
            case 2:
                return "notification_check_due_months_body_two"
            default:
                return "notification_check_due_months_body_other"
            }
        }
    }

    var dateComponents: DateComponents {
        switch unit {
        case .days:
            return DateComponents(day: -multiplier)
        case .months:
            return DateComponents(month: -multiplier)
        }
    }
}

fileprivate extension Date {
    func settingTimeTo(hour: Int) -> Date {
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: self)
        dateComponents.hour = hour
        guard let date = Calendar.current.date(from: dateComponents) else {
            fatalError("Failed to strip time from Date object")
        }
        return date
    }
}
