import SwiftUI

enum WattageStyle {
    static let background = Color(red: 0.035, green: 0.047, blue: 0.075)
    static let card = Color(red: 0.075, green: 0.091, blue: 0.132)
    static let cardElevated = Color(red: 0.105, green: 0.125, blue: 0.175)
    static let ink = Color(red: 0.94, green: 0.96, blue: 1.0)
    static let muted = Color(red: 0.58, green: 0.63, blue: 0.72)
    static let blue = Color(red: 0.35, green: 0.63, blue: 1.0)
    static let mint = Color(red: 0.38, green: 0.91, blue: 0.77)
    static let amber = Color(red: 1.0, green: 0.72, blue: 0.37)
    static let line = Color.white.opacity(0.08)
}

struct WattageCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }
            .padding(18)
            .background(WattageStyle.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(WattageStyle.line, lineWidth: 1))
    }
}

struct Eyebrow: View {
    var title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .tracking(1.3)
            .foregroundStyle(WattageStyle.muted)
    }
}
