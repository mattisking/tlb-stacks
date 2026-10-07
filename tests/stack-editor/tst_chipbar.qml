import QtQuick
import QtTest
import com.mattphilmon.tlbstacks

Rectangle {
    width: 480; height: 400
    CategoryChipBar {
        id: bar
        anchors.fill: parent
        categories: ["ActionGame", "ArcadeGame", "BoardGame", "Audio", "Calculator"]
        selected: ["ActionGame", "BoardGame"]
        caption: "Matches 14 applications"
    }
    SignalSpy { id: spy; target: bar; signalName: "categoryToggled" }
    TestCase {
        name: "CategoryChipBar"
        when: windowShown
        function test_chips_toggle_and_filter() {
            compare(spy.count, 0)
            const arcade = findChild(bar, "chip-ArcadeGame")
            verify(arcade)
            arcade.clicked()
            compare(spy.count, 1)
            compare(spy.signalArguments[0][0], "ArcadeGame")
            verify(spy.signalArguments[0][1])   // was off → toggling selects
            const selected = findChild(bar, "chip-ActionGame")
            selected.clicked()
            compare(spy.signalArguments[1][1], false)  // was on → toggling deselects
        }
        function test_filter_hides_nonmatching_chips() {
            const search = findChild(bar, "chipFilter")
            search.text = "game"
            // The filter model removes non-matching chips from the tree
            // (Repeater destroys delegates), so they are gone, not hidden.
            verify(!findChild(bar, "chip-Audio"))
            verify(findChild(bar, "chip-ActionGame").visible)
        }
        // User's core complaint: "I can't see what Categories are selected."
        // The filter may only narrow the UNSELECTED choices — selected chips
        // stay listed (leading the flow) under any filter text.
        function test_filter_never_hides_selected_chips() {
            // Model level: a filter that excludes both selected names
            // textually keeps them, ahead of the unselected matches.
            const model = bar.chipModel("arcade")
            verify(model.indexOf("ActionGame") >= 0)   // selected, no textual match
            verify(model.indexOf("BoardGame") >= 0)    // selected, no textual match
            verify(model.indexOf("ArcadeGame") >= 0)   // unselected, matches
            verify(model.indexOf("Audio") < 0)         // unselected, narrowed out
            verify(model.indexOf("Calculator") < 0)
            verify(model.indexOf("ActionGame") < model.indexOf("ArcadeGame"))
            verify(model.indexOf("BoardGame") < model.indexOf("ArcadeGame"))
            // Wired Flow: the selected chips survive the same filter.
            const search = findChild(bar, "chipFilter")
            search.text = "arcade"
            verify(findLive(bar, "chip-ActionGame") !== null)
            verify(findLive(bar, "chip-BoardGame") !== null)
            verify(findLive(bar, "chip-ArcadeGame") !== null)
            verify(findLive(bar, "chip-Audio") === null)
            search.text = ""
        }
        // Chips are located through live visual children: Repeater model
        // resets leave removed delegates unparented-but-findable, so
        // findChild can return a dead object after the filter narrows the
        // model. (Same helper as tests/stack-group-runtime/tst_editor.qml.)
        function findLive(item, name) {
            if (item.objectName === name) return item
            const kids = item.children
            for (let i = 0; i < kids.length; i++) {
                const found = findLive(kids[i], name)
                if (found) return found
            }
            return null
        }
    }
}
