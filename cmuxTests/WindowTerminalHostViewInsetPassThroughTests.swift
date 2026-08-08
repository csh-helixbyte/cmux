import AppKit
import Testing

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

/// The floating-panel layout insets every panel from the window frame, so no
/// hosted terminal frame is ever flush to the host's leading edge and no hosted
/// frame ever reaches its trailing edge.
///
/// `shouldPassThroughToSidebarResizer` infers "is a sidebar showing?" from
/// exactly those distances. Both thresholds have to account for the outer inset
/// or the gutters start claiming pointer events as sidebar resizers with no
/// sidebar present.
@MainActor
@Suite("Window terminal host sidebar resizer pass-through with inset panels")
struct WindowTerminalHostViewInsetPassThroughTests {

    // MARK: - Leading Edge

    @Test func insetContentWithNoSidebarKeepsTheLeftGutterOutOfSidebarResizing() throws {
        let fixture = makeFixture()
        let host = fixture.host
        // Sidebar hidden: the content region starts one outer inset in from the
        // window frame, which is as flush to the leading edge as it ever gets.
        host.addSubview(makeHostedTerminalView(frame: NSRect(
            x: FloatingPanelMetrics.outerInset,
            y: 0,
            width: host.bounds.width - (FloatingPanelMetrics.outerInset * 2),
            height: host.bounds.height
        )))

        let pointInGutter = NSPoint(x: FloatingPanelMetrics.outerInset / 2, y: host.bounds.midY)
        #expect(
            host.shouldPassThroughToSidebarResizer(at: pointInGutter) == false,
            """
            With the sidebar hidden the left gutter must route to the terminal, \
            not be claimed as a sidebar resizer.
            """
        )

        let pointOnPanelEdge = NSPoint(x: FloatingPanelMetrics.outerInset, y: host.bounds.midY)
        #expect(
            host.shouldPassThroughToSidebarResizer(at: pointOnPanelEdge) == false,
            "The panel's own leading edge is not a sidebar divider when no sidebar is showing"
        )
    }

    @Test func aShowingSidebarStillHandsItsDividerToTheResizer() throws {
        let fixture = makeFixture()
        let host = fixture.host
        let sidebarDividerX: CGFloat = 220
        host.addSubview(makeHostedTerminalView(frame: NSRect(
            x: sidebarDividerX,
            y: 0,
            width: host.bounds.width - sidebarDividerX - FloatingPanelMetrics.outerInset,
            height: host.bounds.height
        )))

        #expect(
            host.shouldPassThroughToSidebarResizer(at: NSPoint(x: sidebarDividerX, y: host.bounds.midY)),
            "A real sidebar divider must keep receiving resize drags"
        )
    }

    // MARK: - Trailing Edge

    @Test func insetContentWithNoRightSidebarKeepsTheRightGutterOutOfSidebarResizing() throws {
        let fixture = makeFixture()
        let host = fixture.host
        host.addSubview(makeHostedTerminalView(frame: NSRect(
            x: FloatingPanelMetrics.outerInset,
            y: 0,
            width: host.bounds.width - (FloatingPanelMetrics.outerInset * 2),
            height: host.bounds.height
        )))

        let pointInGutter = NSPoint(
            x: host.bounds.maxX - (FloatingPanelMetrics.outerInset / 2),
            y: host.bounds.midY
        )
        #expect(
            host.shouldPassThroughToSidebarResizer(at: pointInGutter) == false,
            """
            With no right sidebar the right gutter must route to the terminal, \
            not be claimed as a trailing sidebar resizer.
            """
        )
    }

    @Test func aTrailingGapThinnerThanTheInsetPlusThresholdIsNotASidebar() throws {
        let fixture = makeFixture()
        let host = fixture.host
        // A 30pt trailing gap is 10pt of outer inset plus 20pt of actual sidebar —
        // under the 24pt threshold that marks a meaningfully visible sidebar.
        // Measuring the raw gap instead would clear the threshold and claim the
        // resizer for a sidebar that is not really there.
        let trailingGap = FloatingPanelMetrics.outerInset + 20
        let contentMaxX = host.bounds.maxX - trailingGap
        host.addSubview(makeHostedTerminalView(frame: NSRect(
            x: FloatingPanelMetrics.outerInset,
            y: 0,
            width: contentMaxX - FloatingPanelMetrics.outerInset,
            height: host.bounds.height
        )))

        #expect(
            host.shouldPassThroughToSidebarResizer(at: NSPoint(x: contentMaxX, y: host.bounds.midY)) == false,
            "The trailing threshold must be measured past the outer inset, not from the window frame"
        )
    }

    @Test func aShowingRightSidebarStillHandsItsDividerToTheResizer() throws {
        let fixture = makeFixture()
        let host = fixture.host
        let rightSidebarDividerX: CGFloat = 520
        host.addSubview(makeHostedTerminalView(frame: NSRect(
            x: FloatingPanelMetrics.outerInset,
            y: 0,
            width: rightSidebarDividerX - FloatingPanelMetrics.outerInset,
            height: host.bounds.height
        )))

        #expect(
            host.shouldPassThroughToSidebarResizer(at: NSPoint(x: rightSidebarDividerX, y: host.bounds.midY)),
            "A real right sidebar divider must keep receiving resize drags"
        )
    }

    // MARK: - Token Invariants

    @Test func theFocusRingStaysInsideTheCardCorner() {
        #expect(FloatingPanelMetrics.ringCornerRadius < FloatingPanelMetrics.cornerRadius)
        #expect(FloatingPanelMetrics.ringCornerRadius >= 0)
        #expect(
            FloatingPanelMetrics.ringCornerRadius
                == FloatingPanelMetrics.cornerRadius - PanelOverlayRingMetrics.inset,
            "The ring is drawn inset from the card edge, so its radius must shrink by the same inset"
        )
        #expect(
            PanelOverlayRingMetrics.cornerRadius == FloatingPanelMetrics.ringCornerRadius,
            "Every ring consumer must track the card radius"
        )
    }

    @Test func theGutterSurvivesBonsplitsDividerThicknessClamp() {
        // A gutter past Bonsplit's clamp would be silently narrowed, leaving the
        // painted layout and the reserved divider band disagreeing.
        #expect(FloatingPanelMetrics.gutter <= 12)
        #expect(FloatingPanelMetrics.gutter > 0)
    }

    // MARK: - Helpers

    /// `shouldPassThroughToSidebarResizer` only counts hosted views that are in a
    /// window, so the host has to be mounted in one for any of this to exercise.
    private final class HostFixture {
        let window: NSWindow
        let host: WindowTerminalHostView

        init(width: CGFloat, height: CGFloat) {
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            host = WindowTerminalHostView(frame: NSRect(x: 0, y: 0, width: width, height: height))
            window.contentView?.addSubview(host)
        }

        deinit {
            window.orderOut(nil)
        }
    }

    private func makeFixture() -> HostFixture {
        HostFixture(width: 900, height: 500)
    }

    private func makeHostedTerminalView(frame: NSRect) -> GhosttySurfaceScrollView {
        let surfaceView = GhosttyNSView(frame: frame)
        let hostedView = GhosttySurfaceScrollView(surfaceView: surfaceView)
        hostedView.frame = frame
        return hostedView
    }
}
