import SwiftUI
import UIKit

enum Theme {
    static let background = Color(hex: 0x040A0A)
    static let mint = Color(hex: 0x49DC7A)
    static let aqua = Color(hex: 0x22F2EF)
    static let orange = Color(hex: 0xFF6B00)
    static let secondary = Color.white.opacity(0.57)
    static func font(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        if UIFont(name: "SatoshiVariable-Bold", size: size) != nil {
            return .custom("SatoshiVariable-Bold", size: size, relativeTo: style).weight(weight)
        }
        let name = weight == .semibold || weight == .bold ? "Satoshi-Bold" : weight == .medium ? "Satoshi-Medium" : "Satoshi-Regular"
        if UIFont(name: name, size: size) != nil { return .custom(name, size: size, relativeTo: style) }
        return .system(size: size, weight: weight)
    }
    static func color(_ nutrient: Nutrient) -> Color {
        switch nutrient {
        case .calories: return orange
        case .protein: return mint
        case .carbohydrates: return aqua
        case .fat: return Color(hex: 0xB4C4BB)
        case .fiber: return Color(hex: 0x79BDA8)
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
            green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}

struct AppBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Theme.background
                RadialGradient(colors: [Color(hex: 0x205847).opacity(0.65), .clear], center: .topTrailing,
                    startRadius: 0, endRadius: proxy.size.height * 0.63)
                Ellipse().fill(Theme.aqua.opacity(0.08)).frame(width: 300, height: 400).blur(radius: 85)
                    .offset(x: -160, y: proxy.size.height * 0.3)
            }
        }.ignoresSafeArea().accessibilityHidden(true)
    }
}

struct GlassCard<Content: View>: View {
    var padding: CGFloat = 20
    @ViewBuilder var content: () -> Content
    var body: some View {
        content().padding(padding).frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LinearGradient(colors: [.white.opacity(0.105), .white.opacity(0.035)], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(LinearGradient(colors: [.white.opacity(0.27), .white.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Theme.orange
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(Theme.font(16, weight: .medium)).frame(maxWidth: .infinity).padding(.vertical, 18)
            .foregroundStyle(color == .white ? Theme.background : .white)
            .background(color.opacity(enabled ? (configuration.isPressed ? 0.7 : 1) : 0.3), in: RoundedRectangle(cornerRadius: 18))
            .opacity(enabled ? 1 : 0.6)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(Theme.font(15, weight: .medium)).frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(.white.opacity(configuration.isPressed ? 0.16 : 0.07), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.12)))
            .foregroundStyle(.white)
    }
}

extension View {
    func inputStyle() -> some View {
        self.padding(14).background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(.white.opacity(0.1)))
            .font(Theme.font(16))
    }
    func appScreen() -> some View {
        self.background { AppBackground() }.foregroundStyle(.white)
            .toolbarBackground(.hidden, for: .navigationBar)
    }
}

struct SectionLabel: View {
    let title: String
    var body: some View { Text(title).font(Theme.font(19, weight: .medium)).frame(maxWidth: .infinity, alignment: .leading) }
}

struct NutrientRows: View {
    let nutrients: Nutrients
    var settings: UserSettings?
    var body: some View {
        VStack(spacing: 20) {
            ForEach(Nutrient.allCases) { nutrient in
                let reference = settings?[nutrient]
                let progress = nutrients.progress(for: nutrient, reference: reference)
                VStack(spacing: 9) {
                    HStack(alignment: .firstTextBaseline) {
                        HStack(spacing: 8) {
                            Circle().fill(Theme.color(nutrient)).frame(width: 6, height: 6)
                            Text(nutrient.title).font(Theme.font(14))
                        }
                        Spacer(minLength: 8)
                        Text("\(NutritionNumber.display(nutrients[nutrient])) \(nutrient.unit)").font(Theme.font(15, weight: .medium)).monospacedDigit()
                        if let reference, reference > 0 {
                            Text("/ \(NutritionNumber.display(reference))").font(Theme.font(12)).foregroundStyle(Theme.secondary)
                        }
                    }
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.08))
                            if let progress {
                                Capsule().fill(Theme.color(nutrient)).frame(width: geometry.size.width * progress)
                            } else {
                                // No denominator: a neutral horizontal track, never an invented percentage.
                                Capsule().fill(.white.opacity(0.12))
                            }
                        }
                    }.frame(height: 5).accessibilityHidden(true)
                }.accessibilityElement(children: .combine)
            }
        }
    }
}

struct InlineError: View {
    let message: String
    var body: some View {
        Label(message, systemImage: "exclamationmark.circle")
            .font(Theme.font(14)).foregroundStyle(Theme.orange).fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("error.message")
    }
}
