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
}
