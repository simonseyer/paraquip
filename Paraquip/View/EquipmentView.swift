//
//  EquipmentView.swift
//  Paraquip
//
//  Created by Simon Seyer on 18.04.21.
//

import SwiftUI

struct EquipmentView: View {

    @EnvironmentObject var store: ProfileStore
    let equipmentId: UUID

    private var equipment: Equipment {
        store.equipment(with: equipmentId)!
    }

    @State private var showingAddEquipment = false
    @State private var editMode: EditMode = .inactive
    @State private var newCheckDate = Date()

    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter
    }()

    var body: some View {
        List {
            Section(header: Text("Equipment")) {
                HStack {
                    Text("Type")
                    Spacer()
                    Text(equipment.localizedType)
                }
                HStack {
                    Text("Brand")
                    Spacer()
                    Text(equipment.brand)
                }
                HStack {
                    Text("Name")
                    Spacer()
                    Text(equipment.name)
                }
                if let paraglider = equipment as? Paraglider {
                    HStack {
                        Text("Size")
                        Spacer()
                        Text(paraglider.size)
                    }
                }
            }
            Section(header: Text("Check")) {
                HStack {
                    Text("Check cycle")
                    Spacer()
                    Text("\(equipment.checkCycle) months")
                }

                HStack {
                    Text("Next check")
                    Spacer()
                    Text(equipment.formattedCheckInterval)
                        .foregroundColor(equipment.checkIntervalColor)
                }

                HStack {
                    DatePicker("Log check", selection: $newCheckDate, displayedComponents: .date)
                    Button(action: {
                        store.logCheck(for: equipment, date: newCheckDate)
                        newCheckDate = Date()
                    }, label: {
                        Image(systemName: "plus.circle.fill")
                    })
                }

            }
            Section(header: HStack {
                Text("Check Log")
                Spacer()
                Button(self.editMode == .inactive ? "Edit" : "Done") {
                    self.editMode = self.editMode == .active ? .inactive : .active
                }
                .disabled(equipment.checkLog.isEmpty)
            }) {
                if equipment.checkLog.isEmpty {
                    Text("No check logged")
                        .foregroundColor(Color(UIColor.systemGray))
                } else {
                    ForEach(equipment.checkLog) { check in
                        Text(dateFormatter.string(from: check.date))
                    }
                    .onDelete(perform: { indexSet in
                        store.removeChecks(for: equipment, atOffsets: indexSet)
                        if equipment.checkLog.isEmpty {
                            editMode = .inactive
                        }
                    })
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .environment(\.editMode, self.$editMode)
        .toolbar(content: {
            Button("Edit") {
                showingAddEquipment = true
            }
        })
        .navigationTitle("\(equipment.brand) \(equipment.name)")
        .sheet(isPresented: $showingAddEquipment) {
            NavigationView {
                EditEquipmentView(equipment: equipment) {
                    showingAddEquipment = false
                }
            }
        }
    }
}

extension Equipment {
    var localizedType: String {
        switch self {
        case is Paraglider:
            return "Paraglider"
        case is Reserve:
            return "Reserve"
        default:
            preconditionFailure("Unknown equipment type")
        }
    }
}

struct EquipmentView_Previews: PreviewProvider {

    private static let profile = Profile.fake()

    static var previews: some View {
        NavigationView {
            EquipmentView(equipmentId: profile.equipment.first!.id)
                .environmentObject(ProfileStore(profile: profile))
        }

        NavigationView {
            EquipmentView(equipmentId: profile.equipment.last!.id)
                .environmentObject(ProfileStore(profile: profile))
        }
    }
}
