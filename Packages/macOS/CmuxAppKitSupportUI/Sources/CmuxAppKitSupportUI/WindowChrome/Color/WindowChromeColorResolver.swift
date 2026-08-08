public import AppKit
public import SwiftUI

/// Resolves color math used by window chrome, titlebar, and backdrop policy.
public struct WindowChromeColorResolver: Sendable {
    /// Creates a color resolver.
    public init() {}

    /// Returns a separator color readable against the given chrome background.
    public func separatorColor(forChromeBackground chrome: NSColor) -> NSColor {
        let srgb = chrome.usingColorSpace(.sRGB) ?? chrome
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        srgb.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
        let isLight = luminance > 0.5
        let amount: CGFloat = isLight ? -0.12 : 0.16
        let separatorAlpha: CGFloat = isLight ? 0.26 : 0.36
        return NSColor(
            red: min(1.0, max(0.0, red + amount)),
            green: min(1.0, max(0.0, green + amount)),
            blue: min(1.0, max(0.0, blue + amount)),
            alpha: separatorAlpha
        )
    }

    /// Returns the recessed ground a raised panel of `surface` sits on.
    ///
    /// The ground is derived from the panel's own fill rather than a fixed hex,
    /// so every terminal theme keeps working and the panel always reads as one
    /// step nearer the viewer than the space around it.
    ///
    /// The luminance branch mirrors ``separatorColor(forChromeBackground:)``:
    /// a dark surface is pulled proportionally toward black, a light surface is
    /// stepped down by a fixed amount so a white panel lands on the familiar
    /// light-gray ground instead of being crushed.
    ///
    /// A near-black surface has no room left below it. Rather than return a
    /// ground indistinguishable from the panel — which would erase the gutters
    /// entirely — the ground is lifted by a small fixed amount, so the boundary
    /// stays visible on pure-black themes.
    public func recessedGroundColor(forSurface surface: NSColor) -> NSColor {
        let srgb = surface.usingColorSpace(.sRGB) ?? surface
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        srgb.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let isLight = relativeLuminance(srgb) > Self.lightSurfaceLuminanceThreshold

        if isLight {
            return NSColor(
                srgbRed: clampedComponent(red - Self.lightSurfaceRecess),
                green: clampedComponent(green - Self.lightSurfaceRecess),
                blue: clampedComponent(blue - Self.lightSurfaceRecess),
                alpha: alpha
            )
        }

        let scale = 1 - Self.darkSurfaceRecessFraction
        let largestChannel = max(red, max(green, blue))
        // Proportional darkening runs out of room as the surface approaches
        // black; below this point the step would be invisible.
        guard largestChannel * Self.darkSurfaceRecessFraction >= Self.minimumRecessDelta else {
            return NSColor(
                srgbRed: clampedComponent(red + Self.nearBlackSurfaceLift),
                green: clampedComponent(green + Self.nearBlackSurfaceLift),
                blue: clampedComponent(blue + Self.nearBlackSurfaceLift),
                alpha: alpha
            )
        }

        return NSColor(
            srgbRed: clampedComponent(red * scale),
            green: clampedComponent(green * scale),
            blue: clampedComponent(blue * scale),
            alpha: alpha
        )
    }

    /// Linear-luminance cutoff separating light from dark surfaces. `0.18`
    /// corresponds to roughly mid-gray in sRGB.
    private static let lightSurfaceLuminanceThreshold: CGFloat = 0.18
    private static let lightSurfaceRecess: CGFloat = 0.06
    private static let darkSurfaceRecessFraction: CGFloat = 0.45
    private static let minimumRecessDelta: CGFloat = 0.012
    private static let nearBlackSurfaceLift: CGFloat = 0.035

    private func clampedComponent(_ value: CGFloat) -> CGFloat {
        min(1.0, max(0.0, value))
    }

    /// Returns `foreground` composited over `background` in sRGB.
    public func compositedColor(_ foreground: NSColor, over background: NSColor) -> NSColor {
        let foregroundColor = foreground.usingColorSpace(.sRGB) ?? foreground
        let backgroundColor = background.usingColorSpace(.sRGB) ?? background
        var foregroundRed: CGFloat = 0
        var foregroundGreen: CGFloat = 0
        var foregroundBlue: CGFloat = 0
        var foregroundAlpha: CGFloat = 0
        var backgroundRed: CGFloat = 0
        var backgroundGreen: CGFloat = 0
        var backgroundBlue: CGFloat = 0
        var backgroundAlpha: CGFloat = 0
        foregroundColor.getRed(&foregroundRed, green: &foregroundGreen, blue: &foregroundBlue, alpha: &foregroundAlpha)
        backgroundColor.getRed(&backgroundRed, green: &backgroundGreen, blue: &backgroundBlue, alpha: &backgroundAlpha)
        _ = backgroundAlpha

        let alpha = max(0, min(foregroundAlpha, 1))
        return NSColor(
            srgbRed: foregroundRed * alpha + backgroundRed * (1 - alpha),
            green: foregroundGreen * alpha + backgroundGreen * (1 - alpha),
            blue: foregroundBlue * alpha + backgroundBlue * (1 - alpha),
            alpha: 1
        )
    }

    /// Returns the color scheme with stronger contrast against `backgroundColor`.
    public func readableColorScheme(for backgroundColor: NSColor) -> ColorScheme {
        let backgroundLuminance = relativeLuminance(backgroundColor)
        let whiteContrast = contrastRatio(backgroundLuminance, 1.0)
        let blackContrast = contrastRatio(backgroundLuminance, 0.0)
        return whiteContrast >= blackContrast ? .dark : .light
    }

    private func contrastRatio(_ lhs: CGFloat, _ rhs: CGFloat) -> CGFloat {
        let lighter = max(lhs, rhs)
        let darker = min(lhs, rhs)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func relativeLuminance(_ color: NSColor) -> CGFloat {
        let srgb = color.usingColorSpace(.sRGB) ?? color
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        srgb.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        _ = alpha

        let linearizedRed = linearized(red)
        let linearizedGreen = linearized(green)
        let linearizedBlue = linearized(blue)
        return 0.2126 * linearizedRed + 0.7152 * linearizedGreen + 0.0722 * linearizedBlue
    }

    private func linearized(_ component: CGFloat) -> CGFloat {
        component <= 0.03928
            ? component / 12.92
            : CGFloat(pow(Double((component + 0.055) / 1.055), 2.4))
    }
}
