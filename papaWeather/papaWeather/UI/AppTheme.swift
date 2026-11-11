//
//  AppTheme.swift
//  papaWeather
//

import SwiftUI

struct ThemeSet {
    let light: ThemePalette
    let dark: ThemePalette

    func palette(for colorScheme: ColorScheme) -> ThemePalette {
        colorScheme == .dark ? dark : light
    }
}

struct ThemePalette {
    let backgroundBase: Color
    let backgroundTop: Color
    let surface: Color
    let surfaceRaised: Color
    let surfaceOverlay: Color
    let accent: Color
    let accentStrong: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let buttonForeground: Color

    var screenBackground: LinearGradient {
        LinearGradient(colors: [backgroundTop, backgroundBase],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var cardBackground: LinearGradient {
        LinearGradient(
            colors: [surface, surfaceRaised],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var cardBorder: LinearGradient {
        LinearGradient(colors: [accentStrong.opacity(0.24), AppTheme.outline],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var buttonBackground: LinearGradient {
        LinearGradient(colors: [accentStrong, accent],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var mutedPanelBackground: LinearGradient {
        LinearGradient(colors: [surfaceRaised, surface],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

enum AppTheme {
    static let outline = Color.white.opacity(0.08)
    static let success = Color(red: 0.314, green: 0.839, blue: 0.506)
    static let warning = Color(red: 1.000, green: 0.741, blue: 0.322)
    static let danger  = Color(red: 1.000, green: 0.450, blue: 0.360)

    static let weather = ThemeSet(
        light: ThemePalette(
            backgroundBase:  Color(red: 0.941, green: 0.969, blue: 0.996),
            backgroundTop:   Color(red: 0.816, green: 0.902, blue: 0.984),
            surface:         Color(red: 0.985, green: 0.993, blue: 1.000),
            surfaceRaised:   Color(red: 0.917, green: 0.953, blue: 0.988),
            surfaceOverlay:  Color(red: 0.655, green: 0.851, blue: 0.965),
            accent:          Color(red: 0.035, green: 0.390, blue: 0.715),
            accentStrong:    Color(red: 0.420, green: 0.792, blue: 1.000),
            textPrimary:     Color(red: 0.055, green: 0.220, blue: 0.369),
            textSecondary:   Color(red: 0.176, green: 0.365, blue: 0.541),
            textTertiary:    Color(red: 0.251, green: 0.409, blue: 0.562),
            buttonForeground: Color.white.opacity(0.97)
        ),
        dark: ThemePalette(
            backgroundBase:  Color(red: 0.031, green: 0.118, blue: 0.235),
            backgroundTop:   Color(red: 0.082, green: 0.267, blue: 0.451),
            surface:         Color(red: 0.102, green: 0.204, blue: 0.318),
            surfaceRaised:   Color(red: 0.074, green: 0.157, blue: 0.271),
            surfaceOverlay:  Color(red: 0.149, green: 0.365, blue: 0.561),
            accent:          Color(red: 0.420, green: 0.792, blue: 1.000),
            accentStrong:    Color(red: 0.675, green: 0.894, blue: 1.000),
            textPrimary:     Color(red: 0.937, green: 0.980, blue: 1.000),
            textSecondary:   Color(red: 0.698, green: 0.835, blue: 0.949),
            textTertiary:    Color(red: 0.514, green: 0.698, blue: 0.824),
            buttonForeground: Color(red: 0.027, green: 0.149, blue: 0.286)
        )
    )
}

// MARK: - Font

extension Font {
    static func transit(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Button style

struct TransitPrimaryButtonStyle: ButtonStyle {
    @Environment(\.themePalette) private var palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.transit(18, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(palette.buttonBackground)
            .foregroundStyle(palette.buttonForeground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(palette.accentStrong.opacity(0.22), lineWidth: 1)
            }
            .shadow(color: palette.accent.opacity(0.28), radius: 16, y: 8)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

// MARK: - Card container

struct CardContainer<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content.transitCardStyle()
    }
}

// MARK: - View modifiers

private struct TransitCardModifier: ViewModifier {
    @Environment(\.themePalette) private var palette
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(palette.cardBorder, lineWidth: 1)
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.20 : 0.08), radius: 12, y: 5)
    }
}

private struct TransitScreenModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let theme: ThemeSet
    let backgroundOverride: LinearGradient?

    private var palette: ThemePalette { theme.palette(for: colorScheme) }

    func body(content: Content) -> some View {
        content
            .environment(\.themePalette, palette)
            .foregroundStyle(palette.textPrimary)
            .tint(palette.accent)
            .background((backgroundOverride ?? palette.screenBackground).ignoresSafeArea())
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(colorScheme, for: .navigationBar)
    }
}

// MARK: - Environment key

private struct ThemePaletteKey: EnvironmentKey {
    static let defaultValue = AppTheme.weather.light
}

extension EnvironmentValues {
    var themePalette: ThemePalette {
        get { self[ThemePaletteKey.self] }
        set { self[ThemePaletteKey.self] = newValue }
    }
}

// MARK: - View extensions

extension View {
    func transitCardStyle() -> some View {
        modifier(TransitCardModifier())
    }

    func screenTheme(_ theme: ThemeSet, backgroundOverride: LinearGradient? = nil) -> some View {
        modifier(TransitScreenModifier(theme: theme, backgroundOverride: backgroundOverride))
    }
}
