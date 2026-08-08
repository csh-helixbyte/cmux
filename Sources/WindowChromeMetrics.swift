import AppKit
import CmuxAppKitSupportUI
import CmuxFoundation
import CoreGraphics

enum WindowChromeMetrics {
    static let sharedChromeBarHeight: CGFloat = 28
    static let appTitlebarHeight: CGFloat = sharedChromeBarHeight
    static let bonsplitTabBarHeight: CGFloat = sharedChromeBarHeight
    static let secondaryTitlebarHeight: CGFloat = sharedChromeBarHeight
    static let minimumTitlebarHeight: CGFloat = sharedChromeBarHeight
    static let maximumTitlebarHeight: CGFloat = 72
    static let defaultTitlebarHeight: CGFloat = sharedChromeBarHeight

    static func clampedTitlebarHeight(_ height: CGFloat) -> CGFloat {
        max(minimumTitlebarHeight, min(maximumTitlebarHeight, height))
    }
}

/// Layout tokens for the floating-panel window look: the sidebar, the terminal
/// panes, and the browser sit on a recessed ground as separate raised cards.
///
/// Every gap here is produced by layout — window-edge padding, split divider
/// thickness, tab-strip spacing — never by a decorative modifier on an ancestor.
/// `TerminalWindowPortal.effectiveAnchorFrameInWindow` reads ancestor *bounds*
/// and never masks, so a `.clipShape` on a parent is invisible to it and the
/// hosted terminal surface would paint straight over the gutter.
///
/// Rounding, by contrast, is only ever a layer property on the hosted surface
/// plus a matching radius on the SwiftUI pane background. It involves no frame
/// math at all.
enum FloatingPanelMetrics {
    /// Window edge to panel.
    static let outerInset: CGFloat = 10

    /// Between panels. Doubles as the split divider thickness, which is what
    /// makes the portal follow the gap for free — the anchor frames shrink.
    ///
    /// Must stay inside Bonsplit's `TabBarMetrics.maximumDividerThickness` (12)
    /// or the clamp would silently shrink the gutter below the painted layout.
    static let gutter: CGFloat = 8

    static let cornerRadius: CGFloat = 10
    static let edgeLineWidth: CGFloat = 1

    static let tabStripHorizontalInset: CGFloat = 8
    static let tabStripBottomGap: CGFloat = 6
    static let tabSpacing: CGFloat = 2
    static let tabCornerRadius: CGFloat = 7

    /// Focus/notification ring radius. The ring is drawn inset from the card
    /// edge, so it must use a correspondingly smaller radius or its corners cut
    /// across the card's own rounding instead of sitting concentric inside it.
    static var ringCornerRadius: CGFloat {
        max(0, cornerRadius - PanelOverlayRingMetrics.inset)
    }
}

/// Colors for the floating-panel look, all derived from the active terminal
/// theme rather than a fixed palette, so every Ghostty theme keeps working.
///
/// Two tones only: the card fill is the terminal background, unchanged, and the
/// ground is that same fill pushed away from the viewer.
@MainActor
enum FloatingPanelChrome {
    private static let resolver = WindowChromeColorResolver()

    /// The recessed ground the cards sit on: window edges, gutters, and the
    /// band behind the detached tab strip.
    static func groundColor(surface: NSColor = GhosttyBackgroundTheme.currentColor()) -> NSColor {
        resolver.recessedGroundColor(forSurface: surface)
    }

    /// The 1px outline around a card. Same color the flat layout used for its
    /// straight hairlines, drawn as a rounded stroke instead.
    static func cardEdgeColor(surface: NSColor = GhosttyBackgroundTheme.currentColor()) -> NSColor {
        resolver.separatorColor(forChromeBackground: surface)
    }

    static func groundHex(surface: NSColor = GhosttyBackgroundTheme.currentColor()) -> String {
        hexString(groundColor(surface: surface))
    }

    static func cardFillHex(surface: NSColor = GhosttyBackgroundTheme.currentColor()) -> String {
        hexString(surface)
    }

    /// `#RRGGBBAA`, the form Bonsplit's chrome color knobs parse.
    static func hexString(_ color: NSColor) -> String {
        let srgb = color.usingColorSpace(.sRGB) ?? color
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        srgb.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func channel(_ value: CGFloat) -> Int {
            Int((min(1, max(0, value)) * 255).rounded())
        }
        return String(
            format: "#%02X%02X%02X%02X",
            channel(red),
            channel(green),
            channel(blue),
            channel(alpha)
        )
    }
}

enum MinimalModeChromeMetrics {
    static let titlebarHeight: CGFloat = WindowChromeMetrics.appTitlebarHeight
}

enum HeaderChromeControlMetrics {
    static let buttonSize: CGFloat = 20
    static let iconSize: CGFloat = 12
    static let iconFrameSize: CGFloat = 14
    static let cornerRadius: CGFloat = 6
    static let titlebarControlsLeadingPadding: CGFloat = 4

    static func iconFrameSize(forIconSize iconSize: CGFloat) -> CGFloat {
        max(Self.iconFrameSize, iconSize + 2)
    }
}

enum RightSidebarChromeMetrics {
    static let titlebarHeight: CGFloat = WindowChromeMetrics.appTitlebarHeight
    static var secondaryBarHeight: CGFloat {
        controlHeight + (barVerticalPadding * 2)
    }
    static let barHorizontalPadding: CGFloat = 8
    static let barVerticalPadding: CGFloat = 4
    static var controlHeight: CGFloat {
        let baseHeight = WindowChromeMetrics.secondaryTitlebarHeight - (barVerticalPadding * 2)
        let scaledTextHeight = GlobalFontMagnification.scaledSize(12)
        let scaledContentHeight = scaledTextHeight + 8
        return max(baseHeight, scaledContentHeight)
    }
    static let controlHorizontalPadding: CGFloat = 8
    static var controlCornerRadius: CGFloat {
        min(10, max(5, controlHeight * 0.25))
    }
    static let headerControlSize: CGFloat = HeaderChromeControlMetrics.buttonSize
    static let headerIconSize: CGFloat = 10
    static let headerIconFrameSize: CGFloat = headerIconSize
    static let headerControlSpacing: CGFloat = 4
    static let headerControlCornerRadius: CGFloat = HeaderChromeControlMetrics.cornerRadius
    static let headerControlCenterAlignmentAdjustment: CGFloat = 0
}

enum SidebarWorkspaceListMetrics {
    static let firstRowTopOffset: CGFloat = MinimalModeChromeMetrics.titlebarHeight + 2
    static let rowVerticalPadding: CGFloat = 8
    static let rowOuterHorizontalPadding: CGFloat = 6
    static let rowContentHorizontalPadding: CGFloat = 10
    static let topScrimHeight: CGFloat = firstRowTopOffset + 20
    static let bottomScrimHeight: CGFloat = topScrimHeight

    static var trailingAccessoryRightEdgeOffset: CGFloat {
        rowOuterHorizontalPadding + rowContentHorizontalPadding
    }

    static func trailingAccessoryCenterOffset(controlWidth: CGFloat) -> CGFloat {
        trailingAccessoryRightEdgeOffset + (controlWidth / 2)
    }

    static var scrollTopInset: CGFloat {
        max(0, firstRowTopOffset - rowVerticalPadding)
    }
}

struct SidebarWorkspaceScrollInsets: Equatable {
    static let workspaceList = SidebarWorkspaceScrollInsets(
        top: SidebarWorkspaceListMetrics.scrollTopInset,
        bottom: SidebarWorkspaceListMetrics.bottomScrimHeight
    )

    let top: CGFloat
    let bottom: CGFloat

    nonisolated var total: CGFloat {
        top + bottom
    }
}

enum SidebarWorkspaceScrollLayout {
    nonisolated static func contentMinHeight(
        viewportHeight: CGFloat,
        insets: SidebarWorkspaceScrollInsets
    ) -> CGFloat {
        // Floor the available height to a whole point. The scroll content is
        // sized to fill exactly `viewportHeight - insets.total`, but on
        // Retina/scaled displays the viewport is frequently fractional and
        // AppKit aligns the laid-out document view's frame to the backing store
        // (rounding up), so a fractional value can land just past the viewport.
        // That sub-point overflow makes the content barely scrollable and shows
        // the auto-hiding overlay scroller even with a single workspace.
        // Flooring to a whole point keeps `content + insets <= viewportHeight`
        // regardless of the display's backing scale, so the phantom scrollbar
        // stays hidden when content fits
        // (https://github.com/manaflow-ai/cmux/issues/3241).
        return max(0, (viewportHeight - insets.total).rounded(.down))
    }
}
