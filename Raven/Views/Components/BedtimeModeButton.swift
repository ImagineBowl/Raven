import SwiftUI

struct BedtimeModeButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AudioPlayerService.self) private var player

    var style: Style = .labeled

    enum Style {
        case labeled
        case iconOnly
    }

    var body: some View {
        Button {
            player.toggleBedtimeMode()
        } label: {
            switch style {
            case .labeled:
                Label(bedtimeLabel, systemImage: "moon.fill")
                    .font(.subheadline)
            case .iconOnly:
                Image(systemName: "moon.fill")
                    .font(.title3)
                    .frame(width: 36, height: 36)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(isActive ? activeColor : Color.secondary)
        .accessibilityLabel("Bedtime mode")
        .accessibilityValue(isActive ? "On" : "Off")
    }

    private var isActive: Bool {
        player.isBedtimeModeEnabled
    }

    private var bedtimeLabel: String {
        isActive ? "Bedtime On" : "Bedtime"
    }

    private var activeColor: Color {
        colorScheme == .dark ? .primary : Color.accentColor
    }
}
