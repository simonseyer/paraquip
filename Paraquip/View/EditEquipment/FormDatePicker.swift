//
//  FormDatePicker.swift
//  Paraquip
//
//  Created by Simon Seyer on 15.05.21.
//

import SwiftUI

struct FormDatePicker: View {

    let label: LocalizedStringKey

    @Binding var date: Date?

    @State private var datePickerShown: Bool = false
    @State private var selectedDate: Date

    @Environment(\.locale) private var locale

    init(label: LocalizedStringKey, date: Binding<Date?>) {
        self.label = label
        self._date = date
        self._selectedDate = State(initialValue: date.wrappedValue ?? Date.paraquipNow)
    }

    var body: some View {
        Group {
            Button(action: {
                date = selectedDate
                withAnimation {
                    datePickerShown.toggle()
                }
            }) {
                HStack {
                    Text(label)
                    Spacer()
                    if date != nil {
                        Text(selectedDate, style: .date)
                        Button(action: { date = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 15))
                        }
                    }
                }
            }
            .foregroundColor(.primary)

            if datePickerShown {
                HStack {
                    DatePicker("",
                               selection: $selectedDate,
                               displayedComponents: .date)
                        .datePickerStyle(.graphical)
                }
            }
        }
        .onChange(of: selectedDate) { value in
            date = value
        }
        .onChange(of: date) { value in
            if let date = value {
                selectedDate = date
            } else {
                withAnimation {
                    datePickerShown = false
                }
            }
        }
    }
}

struct FormDatePicker_Previews: PreviewProvider {
    static var previews: some View {
        Form {
            FormDatePicker(label: "No date", date: .constant(nil))
        }
        Form {
            FormDatePicker(label: "Some date", date: .constant(Date()))
        }
    }
}
