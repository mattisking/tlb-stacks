import QtQuick
import QtTest
import com.mattphilmon.tlbstacks

// Regression tests for the group-bar tip dialog (see the 2026-11-08
// plasmashell Wayland death: an empty StackToolTip dialog was mapped on
// every hover of a context-menu app, and repeated empty shows churned
// surface roles until KWin killed the connection).
//
// The failing sequence, reproduced in testEmptyWhenArmedTilesAreEmptied:
// 1. hover a running-app button (tileMode true arms the 700ms pause timer)
// 2. the app's windows empty mid-pause (tileMode -> false, tilesActive ->
//    false, so the mainItem's implicit size collapses to the text label)
// 3. the pause fires; the new gating keeps `ready` true for any app that
//    offers a context menu, so flipVisible() maps a ZERO-CONTENT dialog.
Rectangle {
    id: host
    width: 400; height: 300

    StackToolTip {
        id: tip
        anchors.fill: parent
        text: ""
        selected: false
        windows: []
    }

    TestCase {
        name: "StackToolTip"
        when: windowShown

        // Simulate hover onset: onReadyChanged -> restart() is the production
        // arming path, so `selected` must toggle false -> true last.
        function resetTip(text, windows, selected) {
            tip.hideToolTip()
            tip.selected = false
            tip.text = text
            tip.windows = windows
            tip.selected = selected
        }

        // The crash reproduction: armed by live tiles, the windows empty
        // mid-pause, and the dialog must never map. Fails on builds without
        // the content guard (shown flips true and Plasma logs
        // "trying to show an empty dialog").
        function test_armed_tiles_emptied_mid_pause_never_map() {
            resetTip("", [{uuid: "u1", winId: 0, title: "w"}], true)
            verify(tip.tileMode, "precondition: one live window means tiles")
            // The window collection empties while the pause timer runs.
            tip.windows = []
            verify(!tip.tileMode, "precondition: no windows means no tiles")
            wait(1000)   // pause interval is 700ms
            verify(!tip.shown, "an emptied tip must never map")
        }

        // Forge's intent: hovering an app that offers a context menu (but has
        // no windows and no error text) shows nothing from TLBStacks — Plasma's
        // contextual actions own the interaction instead.
        function test_context_menu_hover_shows_nothing() {
            resetTip("", [], true)
            wait(1000)
            verify(!tip.shown)
        }

        // The guard must not break the live-tile tip: a running app still
        // gets its tile dialog.
        function test_running_app_still_shows_tiles() {
            resetTip("Some App", [{uuid: "u1", winId: 0, title: "w"}], true)
            wait(1000)
            verify(tip.shown, "live tiles must still show")
            tip.hideToolTip()
        }

        // A tip that is on screen when its windows empty must hide instead of
        // collapsing to degenerate content while mapped.
        function test_shown_tiles_hide_when_windows_empty() {
            resetTip("Some App", [{uuid: "u1", winId: 0, title: "w"}], true)
            wait(1000)
            verify(tip.shown, "precondition: tiles are on screen")
            tip.windows = []
            verify(!tip.shown, "emptying a shown tip's windows hides it")
        }
    }
}
