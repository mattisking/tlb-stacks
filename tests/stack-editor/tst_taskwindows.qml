import QtQuick
import QtTest
import "../../package/contents/ui/TaskWindows.js" as TaskWindows

// The running-app tooltip's tile decisions, extracted so they run offscreen:
// which tip a hover shows (live window tiles vs the plain text) and how a tile
// click routes to a task action and window id. The live thumbnail rendering
// itself (PipeWire on Wayland, WindowThumbnail on X11) is verified on a real
// session, not here.
TestCase {
    name: "TaskWindowTiles"

    function test_running_app_shows_tiles_idle_keeps_text() {
        compare(TaskWindows.showsTiles([{uuid: "u1", winId: 0}]), true)
        compare(TaskWindows.showsTiles([]), false)
        compare(TaskWindows.showsTiles(undefined), false)
        compare(TaskWindows.showsTiles(null), false)
    }

    function test_tile_identity_prefers_the_uuid_then_the_win_id() {
        compare(TaskWindows.windowId({uuid: "u1", winId: 7}), "u1")
        compare(TaskWindows.windowId({uuid: "", winId: 7}), "7")
        compare(TaskWindows.windowId({uuid: "", winId: 0}), "")
        compare(TaskWindows.windowId(null), "")
    }

    function test_tile_clicks_route_to_activate_and_close() {
        const activate = TaskWindows.tileRequest({uuid: "u1", winId: 0}, "left")
        compare(activate.action, "activate")
        compare(activate.id, "u1")

        const middle = TaskWindows.tileRequest({uuid: "u1", winId: 0}, "middle")
        compare(middle.action, "close")
        compare(middle.id, "u1")

        const closeButton = TaskWindows.tileRequest({uuid: "u1", winId: 0}, "close")
        compare(closeButton.action, "close")
        compare(closeButton.id, "u1")

        // An X11 window's WId is driven as a decimal string.
        const x11 = TaskWindows.tileRequest({uuid: "", winId: 42}, "left")
        compare(x11.action, "activate")
        compare(x11.id, "42")

        // A window the model gave no identifier for cannot be driven.
        compare(TaskWindows.tileRequest({uuid: "", winId: 0}, "left"), null)
    }

    // ---- Tooltip placement ----
    // "beside" is the only manual placement left: bar tips are positioned
    // natively by Plasma (visualParent + panel location). Screen 1000x800 at the
    // origin; anchors and tips as noted per case.
    function test_beside_placement_uses_the_host_and_centres_on_the_row() {
        // A popup host spanning x=200..600, hovered row at y=400, tip 200x150:
        // the tip sits past the host's right edge, centred on the row.
        const placed = TaskWindows.placeTip(200, 400, 400, 40, 200, 150, 0, 0, 1000, 800)
        compare(placed.x, 608)          // 200 + 400 + 8
        compare(placed.y, 345)          // 400 + (40 - 150) / 2
    }

    function test_beside_placement_flips_left_when_the_right_edge_is_tight() {
        const placed = TaskWindows.placeTip(700, 400, 200, 40, 200, 150, 0, 0, 1000, 800)
        compare(placed.x, 492)          // 700 - 200 - 8
    }

    function test_beside_placement_clamps_to_the_screen() {
        // Centring would push the tip above the screen; the clamp pins it.
        const top = TaskWindows.placeTip(100, 10, 200, 40, 200, 150, 0, 0, 1000, 800)
        compare(top.y, 0)
        // An oversized tip pins to the screen origin instead of escaping it.
        const huge = TaskWindows.placeTip(100, 400, 200, 40, 5000, 5000, 0, 0, 1000, 800)
        compare(huge.x, 0)
        compare(huge.y, 0)
    }

    // Bar tips hand positioning to Plasma (anchored above the panel edge,
    // clamped by the shell, re-anchored on resize); popup tips place manually.
    function test_bar_tips_select_native_placement() {
        compare(TaskWindows.usesNativePlacement("above"), true)
        compare(TaskWindows.usesNativePlacement("beside"), false)
        compare(TaskWindows.usesNativePlacement(""), false)
        compare(TaskWindows.usesNativePlacement(undefined), false)
        compare(TaskWindows.usesNativePlacement(null), false)
    }

    // ---- Tile arming ----
    // The dialog needs a non-empty mainItem the moment it becomes visible, but
    // nothing may exist while nothing is hovered, so the tiles are armed from the
    // hover through the show (a latch, not the one-shot pause's `running`, which
    // flips false before the pause fires) and cleared on hide.
    function test_tiles_arm_from_the_hover_through_the_show() {
        // Unhovered and unshown: idle, nothing exists.
        compare(TaskWindows.tilesArmed(true, false, false), false)
        // Hovered: armed while the tip is arming, so the dialog is already sized
        // when it flips visible — including when the pause has just stopped.
        compare(TaskWindows.tilesArmed(true, false, true), true)
        // Shown keeps the content after the pause has stopped.
        compare(TaskWindows.tilesArmed(true, true, false), true)
        compare(TaskWindows.tilesArmed(true, true, true), true)
    }

    function test_text_tips_never_arm_tiles() {
        compare(TaskWindows.tilesArmed(false, false, true), false)
        compare(TaskWindows.tilesArmed(false, true, true), false)
        compare(TaskWindows.tilesArmed(false, true, false), false)
    }

    // ---- Flip deferral ----
    // The visible flip waits for the armed content to stop changing size, so the
    // dialog resizes (and natively re-anchors) while still invisible and the
    // first visible frame is already final — with a bound so a thumbnail that
    // never arrives cannot stall the tip.
    function test_show_only_once_the_content_has_settled() {
        // Settled: a real size unchanged since the previous turn.
        compare(TaskWindows.shouldShow(300, 200, 300, 200, 0, 2), true)
        // Unsettled: delegates/thumbnails still arriving.
        compare(TaskWindows.shouldShow(300, 200, 120, 200, 0, 2), false)
        compare(TaskWindows.shouldShow(300, 200, 300, 100, 0, 2), false)
        // Empty content is never settled — but the attempt cap still shows it.
        compare(TaskWindows.shouldShow(0, 0, 0, 0, 0, 2), false)
        compare(TaskWindows.shouldShow(0, 0, 0, 0, 2, 2), true)
        // The cap bounds a size that keeps changing.
        compare(TaskWindows.shouldShow(300, 200, 120, 190, 2, 2), true)
        compare(TaskWindows.shouldShow(300, 200, 120, 190, 1, 2), false)
    }

    // ---- Pointer transit ----
    // The tip must stay on screen while the pointer travels from the anchor to a
    // tile: leaving the anchor alone must not hide it, or the tiles are
    // unreachable.
    function test_tip_stays_visible_through_the_transit() {
        // Still on the anchor: never hide.
        compare(TaskWindows.shouldHide(true, true, false), false)
        // Pointer over the tiles: the tip stays up.
        compare(TaskWindows.shouldHide(false, true, true), false)
        // Away from both, grace elapsed: hide.
        compare(TaskWindows.shouldHide(false, true, false), true)
    }

    function test_text_tips_hide_the_moment_the_anchor_loses_the_pointer() {
        // Not interactive (a text tip): no grace, no hover persistence.
        compare(TaskWindows.shouldHide(false, false, false), true)
        compare(TaskWindows.shouldHide(false, false, true), true)
        compare(TaskWindows.shouldHide(true, false, false), false)
    }

    // The grace has to cover the dead band between the anchor and the tip, where
    // neither surface sees the pointer, without ever pinning the tip for long.
    function test_transit_grace_covers_the_gap_and_is_bounded() {
        // Adjacent (or a small floating-panel band): the usable floor.
        compare(TaskWindows.transitGraceMs(0, 0.5, 250, 600), 250)
        compare(TaskWindows.transitGraceMs(12, 0.5, 250, 600), 250)
        // A real band scales with the crossing distance at a slow pointer speed.
        compare(TaskWindows.transitGraceMs(200, 0.5, 250, 600), 400)
        // Bounded at the ceiling, and a nonsense gap can never go negative.
        compare(TaskWindows.transitGraceMs(320, 0.5, 250, 600), 600)
        compare(TaskWindows.transitGraceMs(100000, 0.5, 250, 600), 600)
        compare(TaskWindows.transitGraceMs(-5, 0.5, 250, 600), 250)
    }

    // ---- Window kind ----
    // A clickable tile tip has to receive button events; the tooltip window type
    // does not reliably deliver them on every platform (hover alone is not enough),
    // so an interactive tip is an ordinary frameless, non-focusable tool window. A
    // text tip stays a pure, input-free tooltip.
    function test_clickable_tips_use_an_interactive_window_kind() {
        compare(TaskWindows.tipWindowKind(true), "tool")
        compare(TaskWindows.tipWindowKind(false), "tooltip")
    }

    // ---- Dialog sizing ----
    // The dialog draws frame margins around its mainItem, so its window size is the
    // content plus those margins — and it has to know that size whenever the content
    // changes while shown, or a growing payload renders clipped.
    function test_dialog_size_adds_the_frame_margins() {
        const size = TaskWindows.dialogSize(436, 164, 4, 4, 4, 4)
        compare(size.width, 444)
        compare(size.height, 172)
    }

    function test_dialog_size_tolerates_absent_or_negative_margins() {
        // A theme that reports no margins yet must not shrink the window below the
        // content, and a missing/NaN reading must not poison the size.
        compare(TaskWindows.dialogSize(436, 164, 0, 0, 0, 0).width, 436)
        compare(TaskWindows.dialogSize(436, 164, 0, 0, 0, 0).height, 164)
        compare(TaskWindows.dialogSize(436, 164, undefined, undefined, undefined, undefined).width, 436)
        compare(TaskWindows.dialogSize(436, 164, -5, -5, -5, -5).height, 164)
    }

    // ---- Native placement ----
    // A natively positioned tip is centred on its anchor item and clamped into the
    // screen, using the CURRENT window width so a correction after a size change
    // recentres it (the dialog's own anchoring does not re-run for a size we wrote).
    function test_centered_x_centres_on_the_anchor() {
        // 1000-wide screen, anchor 60 wide at x=500, 200-wide tip.
        compare(TaskWindows.centeredX(500, 60, 200, 0, 1000), 430)      // 500 + (60-200)/2
    }

    function test_centered_x_clamps_into_the_screen() {
        compare(TaskWindows.centeredX(0, 60, 200, 0, 1000), 0)          // -70 -> left edge
        compare(TaskWindows.centeredX(980, 60, 200, 0, 1000), 800)      // 910 -> right edge
        // An oversized tip pins to the left edge rather than escaping the screen.
        compare(TaskWindows.centeredX(500, 60, 5000, 0, 1000), 0)
    }

    function test_centered_x_follows_the_current_width() {
        // Same anchor and screen, different widths: the stale far-left x of a wide
        // tip must be replaced by the centred x of the narrow one.
        compare(TaskWindows.centeredX(500, 60, 1104, 0, 1000), 0)
        compare(TaskWindows.centeredX(500, 60, 224, 0, 1000), 418)       // 500 + (60-224)/2
    }

    // ---- Tile viewport cap ----
    // The tile row is unbounded by nature (one tile per window), so an app with
    // many windows would make the tip wider than the screen and put its tiles out
    // of reach. The viewport is therefore capped at half the screen span — never
    // below one tile — and the row scrolls inside it.
    function test_tile_viewport_is_uncapped_while_the_row_still_fits() {
        // 224-wide tiles, 8px gaps, 1600px screen (cap = 800).
        compare(TaskWindows.tilesWidth(1, 224, 8, 1600), 224)
        compare(TaskWindows.tilesWidth(3, 224, 8, 1600), 688)    // 3*224 + 2*8
        // The cap is half of the span, and the row does not grow past it.
        compare(TaskWindows.tilesWidth(4, 224, 8, 1600), 800)    // 920 natural -> 800
        compare(TaskWindows.tilesWidth(12, 224, 8, 1600), 800)
    }

    function test_tile_viewport_exactly_at_the_cap_is_kept() {
        // 100-wide tiles, 100px gaps, 1000px screen: cap = 500, and 3 tiles are
        // exactly 500 — at the cap, not over it.
        compare(TaskWindows.tilesWidth(3, 100, 100, 1000), 500)
        compare(TaskWindows.tilesWidth(4, 100, 100, 1000), 500)  // 700 natural
    }

    function test_tile_viewport_never_falls_below_one_tile() {
        // Zero windows: nothing to show (the text-tip branch).
        compare(TaskWindows.tilesWidth(0, 224, 8, 1600), 0)
        // A screen narrower than a single half-span still fits a whole tile, so a
        // cap can never shrink the viewport below one tile.
        compare(TaskWindows.tilesWidth(1, 224, 8, 100), 224)
        compare(TaskWindows.tilesWidth(2, 224, 8, 100), 224)
    }

    function test_tile_viewport_is_monotonic_and_bounded() {
        // Growing the payload never shrinks the viewport and never breaks the cap.
        let previous = -1
        for (let count = 0; count <= 16; ++count) {
            const width = TaskWindows.tilesWidth(count, 224, 8, 1600)
            compare(width >= previous, true)
            compare(width <= 800, true)
            previous = width
        }
    }

    function test_tile_viewport_without_a_known_screen_never_caps() {
        // No usable screen span: keep the natural row rather than guessing a cap.
        compare(TaskWindows.tilesWidth(5, 224, 8, undefined), 1152)   // 5*224 + 4*8
        compare(TaskWindows.tilesWidth(5, 224, 8, NaN), 1152)
    }

    // ---- Wheel scrolling ----
    // The wheel is handled explicitly (the tiles' MouseArea sits between the pointer
    // and the ScrollView, so the view's own wheel handling cannot be relied on), so
    // where a turn lands is decided here: move by the wheel's delta and stop at
    // either end of the row.
    function test_wheel_scroll_moves_the_row_by_the_delta() {
        // A 1756-wide row in a 400-wide viewport scrolls over 0..1356.
        compare(TaskWindows.scrollTarget(0, 120, 1756, 400), 120)
        compare(TaskWindows.scrollTarget(600, 120, 1756, 400), 720)
        compare(TaskWindows.scrollTarget(600, -120, 1756, 400), 480)
        // Both axes are summed by the caller, so a small trackpad step works too.
        compare(TaskWindows.scrollTarget(600, 60 + 60, 1756, 400), 720)
    }

    function test_wheel_scroll_clamps_at_both_ends() {
        // At the start, a turn the other way cannot go negative.
        compare(TaskWindows.scrollTarget(40, -120, 1756, 400), 0)
        // At the end the row is pinned to its last offset.
        compare(TaskWindows.scrollTarget(1356, 120, 1756, 400), 1356)
        // A fast flick lands exactly on the end, never past it.
        compare(TaskWindows.scrollTarget(1200, 1200, 1756, 400), 1356)
        compare(TaskWindows.scrollTarget(60, -1200, 1756, 400), 0)
    }

    function test_wheel_scroll_is_a_no_op_when_the_row_fits_its_viewport() {
        // Nothing to scroll: the offset stays put whatever the wheel says, so a
        // short row never drifts.
        compare(TaskWindows.scrollTarget(0, 120, 216, 216), 0)
        compare(TaskWindows.scrollTarget(0, -120, 216, 216), 0)
        // Even a viewport wider than the content (a reading we should never see).
        compare(TaskWindows.scrollTarget(0, 120, 200, 400), 0)
    }

    function test_wheel_scroll_survives_unusable_readings() {
        // A NaN offset or delta cannot throw the row somewhere arbitrary.
        compare(TaskWindows.scrollTarget(NaN, 120, 1756, 400), 120)
        compare(TaskWindows.scrollTarget(600, NaN, 1756, 400), 600)
        // An unknown content width pins to the start rather than overshooting.
        compare(TaskWindows.scrollTarget(600, 120, NaN, 400), 0)
    }
}
