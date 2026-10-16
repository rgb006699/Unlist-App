import SwiftUI

extension Color {
    /// A color with separate light and dark mode values (hex RGB).
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        func ui(_ hex: UInt32) -> UIColor {
            UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        }
        return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? ui(dark) : ui(light) })
    }
}

// Same status colors as the web app, checked for contrast in both modes.
extension ViewStatus {
    var color: Color {
        switch self {
        case .notChecked: .dynamic(light: 0x5F6A64, dark: 0xA3AEA8)
        case .found: .dynamic(light: 0xA24C12, dark: 0xEB9A5F)
        case .requestSent: .dynamic(light: 0x2456A6, dark: 0x86AEF0)
        case .removed: .dynamic(light: 0x16684A, dark: 0x4CBF8E)
        case .relisted: .dynamic(light: 0xB42332, dark: 0xF07C86)
        case .due: .dynamic(light: 0x8A6100, dark: 0xE3C04F)
        }
    }
}

extension TileGroup {
    var color: Color {
        switch self {
        case .removed: ViewStatus.removed.color
        case .inProgress: ViewStatus.requestSent.color
        case .due: ViewStatus.due.color
        case .notChecked: ViewStatus.notChecked.color
        }
    }
}

struct StatusPill: View {
    let status: ViewStatus

    var body: some View {
        Label(status.label, systemImage: status.symbol)
            .font(.caption.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .foregroundStyle(status.color)
            .background(status.color.opacity(0.13), in: Capsule())
            .fixedSize()
    }
}

struct MethodLabel: View {
    let method: RemovalMethod

    var body: some View {
        Label(method.label, systemImage: method.symbol)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}
