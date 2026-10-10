import SwiftUI
import SwiftData

enum AppTab: String, CaseIterable {
    case today, history, settings
    var title: String {
        switch self { case .today: return "Heute"; case .history: return "Verlauf"; case .settings: return "Einstellungen" }
    }
    var symbol: String {
        switch self { case .today: return "house"; case .history: return "clock.arrow.circlepath"; case .settings: return "gearshape" }
    }
}

enum ComposerRoute: String, Identifiable {
    case manual, photo, text
    var id: String { rawValue }
}

struct RootView: View {
    @State private var tab = AppTab.today
    @State private var composer: ComposerRoute?
    var body: some View {
        ZStack {
            AppBackground()
            TabView(selection: $tab) {
                NavigationStack { DashboardView(isHistory: false) { composer = $0 } }.tag(AppTab.today)
                NavigationStack { DashboardView(isHistory: true) { composer = $0 } }.tag(AppTab.history)
                NavigationStack { SettingsView() }.tag(AppTab.settings)
            }.toolbar(.hidden, for: .tabBar)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { navigation }
        .sheet(item: $composer) { route in
            NavigationStack {
                if route == .manual { MealEditorView(draft: MealDraft()) }
                else { AnalysisComposerView(mode: route) }
            }.preferredColorScheme(.dark).tint(Theme.mint)
        }
    }
    private var navigation: some View {
        HStack(spacing: 8) {
            ForEach(AppTab.allCases, id: \.self) { item in
                Button { tab = item } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab == item && item == .today ? "house.fill" : item.symbol).font(.system(size: 21))
                        Text(item.title).font(Theme.font(11))
                    }.frame(maxWidth: .infinity).padding(.vertical, 12)
                        .foregroundStyle(tab == item ? .white : Theme.secondary)
                        .background(tab == item ? Theme.orange : .clear, in: RoundedRectangle(cornerRadius: 17))
                }.buttonStyle(.plain).accessibilityIdentifier("tab.\(item.rawValue)")
                    .accessibilityAddTraits(tab == item ? [.isSelected] : [])
            }
        }.padding(8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 25))
            .overlay(RoundedRectangle(cornerRadius: 25).stroke(.white.opacity(0.13)))
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 6)
    }
}
