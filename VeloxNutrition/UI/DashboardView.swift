import SwiftUI
import SwiftData

struct DashboardView: View {
    let isHistory: Bool
    let add: (ComposerRoute) -> Void
    @Query(sort: \Meal.date, order: .reverse) private var meals: [Meal]
    @Query private var settings: [UserSettings]
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedDate = Date.now
    @State private var detail: Meal?
    @State private var showDatePicker = false
    private var day: Date { isHistory ? selectedDate : .now }
    private var dayMeals: [Meal] { meals.filter { DayRange.contains($0.date, in: day) } }
    private var totals: Nutrients { Nutrients.sum(dayMeals.map(\.nutrients)) }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { _ in
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    header
                    if isHistory { dateNavigation }
                    else { Text("Dein Tag.\nAuf einen Blick.").font(Theme.font(35, weight: .medium, relativeTo: .largeTitle)).lineSpacing(1) }
                    overview
                    if !isHistory { addMethods }
                    HStack {
                        SectionLabel(title: isHistory ? "Mahlzeiten" : "Deine Mahlzeiten")
                        Text("\(dayMeals.count)").font(Theme.font(14)).foregroundStyle(Theme.secondary)
                    }
                    if dayMeals.isEmpty {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Image(systemName: "fork.knife").font(.system(size: 26)).foregroundStyle(Theme.mint)
                                Text("Noch keine Mahlzeiten").font(Theme.font(18, weight: .medium))
                                Text(isHistory ? "Für diesen Tag sind keine Einträge gespeichert." : "Ein Foto, ein paar Worte oder deine eigenen Werte – halte fest, was du gegessen hast.")
                                    .font(Theme.font(14)).foregroundStyle(Theme.secondary)
                            }.padding(.vertical, 10)
                        }
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(dayMeals) { meal in
                                Button { detail = meal } label: { MealRow(meal: meal) }.buttonStyle(.plain)
                                    .accessibilityIdentifier("meal.row")
                            }
                        }
                    }
                    Text("Lokal auf deinem iPhone gespeichert").font(Theme.font(11)).foregroundStyle(Theme.secondary)
                        .frame(maxWidth: .infinity).padding(.top, 8)
                }.padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 24)
            }.appScreen()
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $detail) { meal in NavigationStack { MealDetailView(meal: meal) }.preferredColorScheme(.dark) }
        .sheet(isPresented: $showDatePicker) {
            NavigationStack {
                DatePicker("Tag auswählen", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical).padding().appScreen().navigationTitle("Tag auswählen")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { showDatePicker = false } } }
            }.presentationDetents([.medium]).preferredColorScheme(.dark)
        }
    }
    private var header: some View {
        HStack {
            HStack(spacing: 9) {
                Image(systemName: "leaf.fill").foregroundStyle(Theme.mint).font(.system(size: 23))
                Text("Velox").font(Theme.font(23, weight: .medium))
                Text("Nutrition").font(Theme.font(13)).foregroundStyle(Theme.secondary)
            }
            Spacer()
            Text(isHistory ? "Verlauf" : Date.now.formatted(.dateTime.day().month(.abbreviated)))
                .font(Theme.font(12)).foregroundStyle(Theme.secondary)
        }
    }
    private var dateNavigation: some View {
        HStack(spacing: 10) {
            Button { moveDay(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44).background(.white.opacity(0.07), in: Circle()) }
                .accessibilityLabel("Vorheriger Tag")
            Button { showDatePicker = true } label: {
                VStack(spacing: 5) {
                    Text(Calendar.current.isDateInToday(day) ? "Heute" : day.formatted(.dateTime.weekday(.wide))).font(Theme.font(27, weight: .medium))
                    Text(day.formatted(.dateTime.day().month(.wide).year())).font(Theme.font(13)).foregroundStyle(Theme.secondary)
                }.frame(maxWidth: .infinity)
            }
            Button { moveDay(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44).background(.white.opacity(0.07), in: Circle()) }
                .accessibilityLabel("Nächster Tag")
        }.buttonStyle(.plain)
    }
    private func moveDay(_ step: Int) { selectedDate = Calendar.current.date(byAdding: .day, value: step, to: selectedDate) ?? selectedDate }

    private var overview: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 23) {
                HStack {
                    Text("TAGESÜBERSICHT").font(Theme.font(11, weight: .medium)).tracking(2).foregroundStyle(Theme.secondary)
                    Spacer()
                    Image(systemName: "chart.bar.xaxis").foregroundStyle(Theme.mint)
                }
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(NutritionNumber.display(totals.calories)).font(Theme.font(49, weight: .medium, relativeTo: .largeTitle)).monospacedDigit()
                        .accessibilityIdentifier("dashboard.calories")
                    Text("kcal").font(Theme.font(17)).foregroundStyle(Theme.secondary)
                    Spacer()
                    Text("erfasst").font(Theme.font(12)).foregroundStyle(Theme.secondary)
                }
                Divider().overlay(.white.opacity(0.12))
                NutrientRows(nutrients: totals, settings: settings.first)
                if settings.first.map({ s in Nutrient.allCases.allSatisfy { s[$0] == nil } }) ?? true {
                    Text("Referenzwerte sind optional. Du kannst sie in den Einstellungen ergänzen.").font(Theme.font(11)).foregroundStyle(Theme.secondary)
                }
            }
        }
    }
    private var addMethods: some View {
        VStack(spacing: 10) {
            Button { add(.photo) } label: { Label("Mahlzeit fotografieren", systemImage: "camera.fill") }
                .buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("add.photo")
            HStack(spacing: 10) {
                Button { add(.text) } label: { Label("Beschreiben", systemImage: "waveform") }.accessibilityIdentifier("add.text")
                Button { add(.manual) } label: { Label("Manuell", systemImage: "plus") }.accessibilityIdentifier("add.manual")
            }.buttonStyle(SecondaryButtonStyle())
        }
    }
}

struct MealRow: View {
    let meal: Meal
    var body: some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    MealPhoto(filename: meal.photoFilename, size: 58)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(meal.name).font(Theme.font(17, weight: .medium)).multilineTextAlignment(.leading)
                        Text(meal.date.formatted(.dateTime.hour().minute())).font(Theme.font(12)).foregroundStyle(Theme.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(Theme.secondary)
                }
                HStack {
                    Text("\(NutritionNumber.display(meal.calories)) kcal").font(Theme.font(18, weight: .medium))
                    Spacer()
                    Text(meal.source == "manual" ? "Manuell" : "KI · geprüft").font(Theme.font(10)).foregroundStyle(Theme.secondary)
                }
                FlowMacros(nutrients: meal.nutrients)
            }
        }.accessibilityElement(children: .combine)
    }
}

struct FlowMacros: View {
    let nutrients: Nutrients
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 7) {
            ForEach(Nutrient.allCases.filter { $0 != .calories }) { nutrient in
                HStack(spacing: 5) {
                    Circle().fill(Theme.color(nutrient)).frame(width: 4, height: 4)
                    Text("\(nutrient.title) \(NutritionNumber.display(nutrients[nutrient])) g").font(Theme.font(11)).foregroundStyle(Theme.secondary)
                }
            }
        }
    }
}

struct MealPhoto: View {
    var filename: String?
    var jpeg: Data?
    var size: CGFloat = 70
    @State private var image: UIImage?
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            else { ZStack { Theme.mint.opacity(0.1); Image(systemName: "fork.knife").foregroundStyle(Theme.mint) } }
        }.frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: 14)).accessibilityHidden(true)
            .task(id: filename) { image = (jpeg ?? PhotoStore().read(filename)).flatMap { UIImage(data: $0) } }
            .onChange(of: jpeg) { _, data in image = (data ?? PhotoStore().read(filename)).flatMap { UIImage(data: $0) } }
    }
}
