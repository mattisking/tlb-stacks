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
    }
}
