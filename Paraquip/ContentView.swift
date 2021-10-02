//
//  ContentView.swift
//  Paraquip
//
//  Created by Simon Seyer on 09.04.21.
//

import SwiftUI

struct ContentView: View {

    enum Tabs: String {
        case profile, notifications
    }

    @ObservedObject var viewModel: SetViewModel
    @EnvironmentObject var notificationsStore: NotificationsStore

    @State private var selectedTab: Tabs = .profile
    @State private var selectedEquipment: UUID? = nil

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                SetView(viewModel: viewModel)
            }
            .tabItem {
                Label("Equipment", systemImage: "book.closed.fill")
            }
            .tag(Tabs.profile)
            
            NavigationView {
                NotificationSettingsView()
            }
            .tabItem {
                Label("Notifications", systemImage: "bell.fill")
            }
            .tag(Tabs.notifications)
        }
        .onChange(of: notificationsStore.navigationState, perform: { value in
            switch value {
            case .notificationSettings:
                selectedTab = .notifications
            case .equipment(let equipmentId):
                selectedTab = .profile
                selectedEquipment = equipmentId
            case .none:
                break
            }
            notificationsStore.resetNavigationState()
        })
    }
}

struct ContentView_Previews: PreviewProvider {

    static let appStore = FakeAppStore()

    static var previews: some View {
        ContentView(viewModel: SetViewModel(store: appStore))
            .environmentObject(NotificationsStore(profileStore: appStore.mainProfileStore))
    }
}

