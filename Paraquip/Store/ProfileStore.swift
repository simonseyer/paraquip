//
//  ProfileStore.swift
//  Paraquip
//
//  Created by Simon Seyer on 01.05.21.
//

import Foundation

class ProfileStore: ObservableObject {

    @Published var profile: Profile

    init(profile: Profile) {
        self.profile = profile
    }

    func update(name: String) {
        profile.name = name
    }

    func store(equipment: Equipment) {
        if let index = profile.equipment.firstIndex(where: { $0.id == equipment.id }) {
            profile.equipment[index] = equipment
        } else {
            profile.equipment.append(equipment)
        }
    }

    func removeEquipment(atOffsets indexSet: IndexSet) {
        profile.equipment.remove(atOffsets: indexSet)
    }

    func logCheck(for equipment: Equipment, date: Date) {
        if let index = profile.equipment.firstIndex(where: { $0.id == equipment.id }) {
            profile.equipment[index].checkLog.append(Check(date: date))
        }
    }

    func removeChecks(for equipment: Equipment, atOffsets indexSet: IndexSet) {
        if let index = profile.equipment.firstIndex(where: { $0.id == equipment.id }) {
            profile.equipment[index].checkLog.remove(atOffsets: indexSet)
        }
    }
}