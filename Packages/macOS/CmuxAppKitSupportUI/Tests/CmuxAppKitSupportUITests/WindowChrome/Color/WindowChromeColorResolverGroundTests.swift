import AppKit
import Testing

@testable import CmuxAppKitSupportUI

/// The floating-panel ground is derived from the panel's own fill so every
/// terminal theme keeps working. What must hold on every branch is that the
/// ground and the panel are visibly different, and that the panel never ends up
/// looking recessed relative to its surroundings.
@Suite struct WindowChromeColorResolverGroundTests {
    private let resolver = WindowChromeColorResolver()

    // MARK: - Dark Surfaces

    @Test func aDarkSurfaceGetsAGroundPulledTowardBlack() {
        let surface = NSColor(srgbRed: 0.12, green: 0.13, blue: 0.15, alpha: 1)
        let ground = resolver.recessedGroundColor(forSurface: surface)

        #expect(luminance(of: ground) < luminance(of: surface))
        #expect(isVisiblyDifferent(ground, from: surface))
    }

    @Test func aNearBlackSurfaceStillGetsAVisibleGround() {
        // Pure black has no room left below it. Returning the same color would
        // erase the gutters entirely, so the ground is lifted instead.
        let surface = NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
        let ground = resolver.recessedGroundColor(forSurface: surface)

        #expect(isVisiblyDifferent(ground, from: surface))
        #expect(luminance(of: ground) > luminance(of: surface))
    }

    // MARK: - Light Surfaces

    @Test func aLightSurfaceGetsAStepDownIntoGray() {
        let surface = NSColor(srgbRed: 0.98, green: 0.98, blue: 0.97, alpha: 1)
        let ground = resolver.recessedGroundColor(forSurface: surface)

        #expect(luminance(of: ground) < luminance(of: surface))
        #expect(isVisiblyDifferent(ground, from: surface))
    }

    @Test func aWhiteSurfaceLandsOnTheFamiliarLightGrayGround() {
        let ground = resolver.recessedGroundColor(forSurface: .white)
        let components = srgbComponents(ground)

        #expect(components.red < 1)
        #expect(components.red > 0.85, "A white panel's ground should read as light gray, not as a shadow")
    }

    // MARK: - Invariants

    @Test func everyChannelStaysInRange() {
        let surfaces: [NSColor] = [
            .white,
            .black,
            NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1),
            NSColor(srgbRed: 0.02, green: 0.02, blue: 0.02, alpha: 1),
            NSColor(srgbRed: 0.5, green: 0.5, blue: 0.5, alpha: 1),
        ]

        for surface in surfaces {
            let components = srgbComponents(resolver.recessedGroundColor(forSurface: surface))
            #expect((0...1).contains(components.red))
            #expect((0...1).contains(components.green))
            #expect((0...1).contains(components.blue))
            #expect((0...1).contains(components.alpha))
        }
    }

    @Test func theSurfaceAlphaIsPreserved() {
        let surface = NSColor(srgbRed: 0.1, green: 0.1, blue: 0.1, alpha: 0.8)
        let ground = resolver.recessedGroundColor(forSurface: surface)

        #expect(abs(srgbComponents(ground).alpha - 0.8) < 0.002)
    }

    @Test func aHueTintedSurfaceKeepsItsHueInTheGround() {
        // The ground is the same theme one step back, not a neutral gray, or a
        // tinted theme would show a foreign-colored gutter.
        let surface = NSColor(srgbRed: 0.10, green: 0.16, blue: 0.28, alpha: 1)
        let components = srgbComponents(resolver.recessedGroundColor(forSurface: surface))

        #expect(components.blue > components.green)
        #expect(components.green > components.red)
    }

    // MARK: - Helpers

    private func srgbComponents(
        _ color: NSColor
    ) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        let srgb = color.usingColorSpace(.sRGB) ?? color
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        srgb.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (red, green, blue, alpha)
    }

    private func luminance(of color: NSColor) -> CGFloat {
        let components = srgbComponents(color)
        return 0.299 * components.red + 0.587 * components.green + 0.114 * components.blue
    }

    private func isVisiblyDifferent(_ lhs: NSColor, from rhs: NSColor) -> Bool {
        abs(luminance(of: lhs) - luminance(of: rhs)) >= 0.01
    }
}
