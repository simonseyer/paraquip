//
//  EditEquipmentView.swift
//  Paraquip
//
//  Created by Simon Seyer on 18.04.21.
//

import SwiftUI
import CoreData

extension NumberFormatter {
    func string(from doubleValue: Double) -> String? {
        return string(from: NSNumber(value: doubleValue))
    }

    func value(from string: String) -> Double? {
        return number(from: string)?.doubleValue
    }
}

extension Locale {
    var weightUnit: UnitMass {
        usesMetricSystem ? .kilograms : .pounds
    }
}

fileprivate struct LogDateCell: View {

    @ObservedObject var logEntry: LogEntry

    var body: some View {
        Text(logEntry.logEntryDate, format: Date.FormatStyle(date: .abbreviated, time: .omitted))
    }
}

struct EditEquipmentView: View {

    enum Field {
        case customBrand
        case name
        case weight
        case purchaseDate
        case minimumWeight
        case maximumWeight
    }

    @ObservedObject var equipment: Equipment

    @Environment(\.managedObjectContext) private var managedObjectContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) var locale: Locale

    @State private var editLogEntryOperation: Operation<LogEntry>?
    @State private var createLogEntryOperation: Operation<LogEntry>?
    @State private var showingManualPicker = false
    @State private var showingPurchaseView = false
    @State private var weight: String = ""
    @State private var minWeight: String = ""
    @State private var maxWeight: String = ""
    @FocusState private var focusedField: Field?

    private let weightUnitText: String
    private let weightFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 1
        return formatter
    }()
    private let weightRangeFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private var title: Text {
        if !equipment.brandName.isEmpty {
            return Text("\(equipment.brandName) \(NSLocalizedString(equipment.localizedType, comment: ""))")
        } else {
            return Text("\(NSLocalizedString("New", comment: "")) \(NSLocalizedString(equipment.localizedType, comment: ""))")
        }
    }

    init(equipment: Equipment, locale: Locale) {
        self.equipment = equipment

        let formatter = MeasurementFormatter()
        formatter.locale = locale
        formatter.unitStyle = .short
        weightUnitText = formatter.string(from: locale.weightUnit)

        if let equipmentWeight = equipment.weightMeasurement {
            let value = equipmentWeight.converted(to: locale.weightUnit).value
            _weight = State(initialValue: weightFormatter.string(from: value) ?? "")
        }
        
        if let weightRange = equipment.weightRangeMeasurement {
            let minValue = weightRange.lowerBound.converted(to: locale.weightUnit).value
            let maxValue = weightRange.upperBound.converted(to: locale.weightUnit).value
            _minWeight = State(initialValue: weightRangeFormatter.string(from: minValue) ?? "")
            _maxWeight = State(initialValue: weightRangeFormatter.string(from: maxValue) ?? "")
        }
    }

    var body: some View {
        Form {
            Section(header: Text("")) {
                Picker(selection: $equipment.equipmentBrand, label: Text("Brand")) {
                    ForEach(Brand.allCases) { brand in
                        BrandRow(brand: brand)
                            .tag(brand)
                    }
                }
                if case .custom = equipment.equipmentBrand {
                    HStack {
                        Text("Custom brand")
                        Spacer()
                        TextField("", text: $equipment.brandName)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .customBrand)
                    }
                }
                HStack {
                    Text("Name")
                    Spacer()
                    TextField("", text: $equipment.equipmentName)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .name)
                }
                Picker(selection: $equipment.equipmentSize, label: Text("Size")) {
                    ForEach(Equipment.Size.allCases) { size in
                        Text(size.rawValue)
                            .tag(size)
                    }
                }
                HStack {
                    Text("Weight")
                    Spacer()
                    TextField("", text: $weight)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .weight)
                    Text(weightUnitText)
                        .foregroundColor(.secondary)
                }
                NavigationLink(isActive: $showingPurchaseView) {
                    if showingPurchaseView {
                        let logEntry: LogEntry = {
                            let logEntry = equipment.purchaseLog ?? LogEntry.create(context: managedObjectContext)
                            equipment.purchaseLog = logEntry
                            return logEntry
                        }()
                        LogEntryView(logEntry: logEntry, mode: .inline)
                            .environment(\.managedObjectContext, managedObjectContext)
                            .toolbar {
                                Button("Clear", role: .destructive) {
                                    managedObjectContext.delete(logEntry)
                                    showingPurchaseView = false
                                }
                            }
                    }
                } label: {
                    Text("Purchase")
                    Spacer()
                    if let purchaseLog = equipment.purchaseLog {
                        LogDateCell(logEntry: purchaseLog)
                    }
                }
            }
            if equipment is Paraglider || equipment is Reserve {
                Section(header: Text("Weight range")) {
                    if equipment is Paraglider {
                        HStack {
                            Text("Minimum weight")
                            Spacer()
                            TextField("", text: $minWeight)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numberPad)
                                .focused($focusedField, equals: .minimumWeight)
                            Text(weightUnitText)
                                .foregroundColor(.secondary)
                        }
                    }
                    HStack {
                        Text("Maximum weight")
                        Spacer()
                        TextField("", text: $maxWeight)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .maximumWeight)
                        Text(weightUnitText)
                            .foregroundColor(.secondary)
                    }
                }
            }
            Section(header: Text("Check cycle")) {
                CheckCycleRow(checkCycle: $equipment.floatingCheckCycle)
            }
            if equipment.isInserted {
                Section(header: Text("Next steps")) {
                    Button(action: {
                        if let logEntry = equipment.allChecks.first {
                            editLogEntryOperation = Operation(editing: logEntry,
                                                              withParentContext: managedObjectContext)
                        } else {
                            let operation = Operation<LogEntry>(withParentContext: managedObjectContext)
                            operation.object(for: equipment).addToCheckLog(operation.object)
                            createLogEntryOperation = operation
                        }
                    }) {
                        HStack {
                            FormIcon(icon: Image(systemName: "checkmark.circle.fill"))
                                .padding(.trailing, 8)
                            Text("Log last check")
                            Spacer()
                            if !equipment.allChecks.isEmpty {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color.green)
                            }
                        }
                        .foregroundColor(.primary)
                        .padding([.top, .bottom], 6)
                    }

                    Button(action: { showingManualPicker = true }) {
                        HStack {
                            FormIcon(icon: Image(systemName: "book.fill"))
                                .padding(.trailing, 8)
                            Text("Attach Manual")
                            Spacer()
                            if equipment.manualAttachment != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color.green)
                            }
                        }
                        .foregroundColor(.primary)
                        .padding([.top, .bottom], 6)
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                Button("Done") {
                    focusedField = nil
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if let weight = weightFormatter.value(from: weight) {
                        equipment.weightMeasurement = .init(value: weight, unit: locale.weightUnit)
                    } else {
                        equipment.weightMeasurement = nil
                    }

                    let minWeight = weightRangeFormatter.value(from: minWeight)
                    let maxWeight = weightRangeFormatter.value(from: maxWeight)
                    if let maxWeight = maxWeight {
                        let sanitizedMinWeight = minWeight ?? 0
                        let sanitizedMaxWeight = max(maxWeight, sanitizedMinWeight)

                        let minMeasurement = Measurement<UnitMass>(value: sanitizedMinWeight, unit: locale.weightUnit)
                        let maxMeasurement = Measurement<UnitMass>(value: sanitizedMaxWeight, unit: locale.weightUnit)
                        equipment.weightRangeMeasurement = minMeasurement...maxMeasurement
                    } else {
                        equipment.weightRangeMeasurement = nil
                    }

                    try! managedObjectContext.save()
                    dismiss()
                }
                .disabled(equipment.equipmentBrand == .none || equipment.equipmentName.isEmpty)
            }
        }
        .sheet(item: $editLogEntryOperation) { operation in
            NavigationView {
                LogEntryView(logEntry: operation.object, mode: .edit)
                    .environment(\.managedObjectContext, operation.childContext)
            }
        }
        .sheet(item: $createLogEntryOperation) { operation in
            NavigationView {
                LogEntryView(logEntry: operation.object, mode: .create)
                    .environment(\.managedObjectContext, operation.childContext)
            }
        }
        .sheet(isPresented: $showingManualPicker) {
            DocumentPicker(contentTypes: [.pdf]) { url in
                let attachment = Attachment.create(fileURL: url,
                                                   context: managedObjectContext)
                equipment.manualAttachment = attachment
            }
        }
    }
}

struct AddEquipmentView_Previews: PreviewProvider {

    static var locale: Locale = .init(identifier: "de")

    static var previews: some View {
        Group {
            NavigationView {
                EditEquipmentView(equipment: Paraglider.create(context: CoreData.previewContext), locale: locale)
            }
            ForEach(CoreData.fakeProfile.allEquipment) { equipment in
                NavigationView {
                    EditEquipmentView(equipment: equipment, locale: locale)
                }
            }
        }
        .environment(\.locale, locale)
        .environment(\.managedObjectContext, CoreData.previewContext)
    }
}
