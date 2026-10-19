import SwiftUI

struct ScreenHeader: View {
    var subtitle: String
    var showSettings: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(LinearGradient(colors: [WattageStyle.blue, WattageStyle.mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "bolt.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(WattageStyle.background)
            }
            .frame(width: 39, height: 39)

            VStack(alignment: .leading, spacing: 2) {
                Text("Wattage")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(WattageStyle.ink)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(WattageStyle.muted)
            }
            Spacer()
            if let showSettings {
                Button(action: showSettings) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(WattageStyle.ink)
                        .frame(width: 42, height: 42)
                        .background(WattageStyle.card, in: Circle())
                }
                .accessibilityLabel("Settings")
            }
        }
    }
}

struct SectionHeading: View {
    var title: String
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(WattageStyle.ink)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(WattageStyle.muted)
            }
        }
    }
}

struct EmptyState: View {
    var symbol: String
    var title: String
    var detail: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(WattageStyle.mint)
                .frame(width: 56, height: 56)
                .background(WattageStyle.cardElevated, in: Circle())
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(WattageStyle.ink)
            Text(detail)
                .font(.system(size: 13))
                .foregroundStyle(WattageStyle.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

struct MetricValue: View {
    var value: String
    var unit: String
    var title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Eyebrow(title: title)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 23, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(WattageStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(unit)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(WattageStyle.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
