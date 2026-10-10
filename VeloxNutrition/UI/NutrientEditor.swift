import SwiftUI

struct NutrientEditor: View {
    @Binding var nutrients: Nutrients
    @Binding var invalidFields: Set<String>
    var prefix = "total"
    var body: some View {
        VStack(spacing: 13) {
            ForEach(Nutrient.allCases) { nutrient in
                NumericField(title: nutrient.title, unit: nutrient.unit,
                    value: Binding(get: { nutrients[nutrient] }, set: { nutrients[nutrient] = $0 }),
                    invalidFields: $invalidFields, fieldID: "\(prefix).\(nutrient.rawValue)")
            }
        }
    }
}

struct NumericField: View {
    let title: String
    let unit: String
    @Binding var value: Double
    @Binding var invalidFields: Set<String>
    let fieldID: String
    @State private var text = ""
    @FocusState private var focused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 12) {
                Text(title).font(Theme.font(14)).frame(maxWidth: .infinity, alignment: .leading)
                TextField("0", text: $text).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    .focused($focused).inputStyle().frame(width: 115).accessibilityLabel(title)
                    .accessibilityIdentifier("value.\(fieldID)")
                Text(unit).font(Theme.font(12)).foregroundStyle(Theme.secondary).frame(width: 30, alignment: .leading)
            }
            if invalidFields.contains(fieldID) {
                Text("Bitte eine Zahl ab 0 eingeben.").font(Theme.font(11)).foregroundStyle(Theme.orange)
            }
        }
        .onAppear { text = NutritionNumber.edit(value) }
        .onChange(of: text) { _, input in
            if let parsed = NutritionNumber.parse(input) { invalidFields.remove(fieldID); value = parsed }
            else { invalidFields.insert(fieldID) }
        }
        .onChange(of: value) { _, number in
            if NutritionNumber.parse(text) != number { text = NutritionNumber.edit(number) }
        }
    }
}

struct ReferenceField: View {
    let nutrient: Nutrient
    @Binding var value: Double?
    @Binding var invalidFields: Set<String>
    @State private var text = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(nutrient.title).font(Theme.font(14)).frame(maxWidth: .infinity, alignment: .leading)
                TextField("Optional", text: $text).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    .inputStyle().frame(width: 120).accessibilityLabel("Referenzwert \(nutrient.title)")
                Text(nutrient.unit).font(Theme.font(12)).foregroundStyle(Theme.secondary).frame(width: 30)
            }
            if invalidFields.contains(nutrient.rawValue) { InlineError(message: "Leer lassen oder eine Zahl größer als 0 eintragen.") }
        }
        .onAppear { text = value.map(NutritionNumber.edit) ?? "" }
        .onChange(of: text) { _, input in
            if input.trimmingCharacters(in: .whitespaces).isEmpty {
                value = nil; invalidFields.remove(nutrient.rawValue)
            } else if let parsed = NutritionNumber.parse(input), parsed > 0 {
                value = parsed; invalidFields.remove(nutrient.rawValue)
            } else { invalidFields.insert(nutrient.rawValue) }
        }
        .onChange(of: value) { _, number in
            if NutritionNumber.parse(text) != number { text = number.map(NutritionNumber.edit) ?? "" }
        }
    }
}
