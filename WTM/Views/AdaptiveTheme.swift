import SwiftUI

enum AdaptiveTheme {
    static func backgroundScrimOpacity(for colorScheme: ColorScheme) -> Double {
        colorScheme == .dark ? 0.18 : 0.42
    }

    static func cardFill(for colorScheme: ColorScheme) -> AnyShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(.ultraThinMaterial)
        }
        return AnyShapeStyle(Color.black.opacity(0.48))
    }

    static func cardStroke(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.22) : Color.white.opacity(0.34)
    }

    static func controlFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.2)
    }

    static func controlStroke(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.22) : Color.white.opacity(0.34)
    }

    static func chromeFill(for colorScheme: ColorScheme) -> AnyShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(Color.black.opacity(0.35))
        }
        return AnyShapeStyle(Color.black.opacity(0.55))
    }
}
