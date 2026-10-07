import QtQuick
import QtTest
import com.mattphilmon.tlbstacks
TestCase {
    name: "ActivityRefreshNotifications"
    ActivitySource { id: source }
    SignalSpy { id: entriesSpy; target: source; signalName: "entriesChanged" }
    function test_identical_empty_refresh_does_not_reset_menu() {
        // Deliberately unmatched category avoids depending on personal history.
        source.refresh(false, 10, ["TLBStacksTestUnmatchedCategory81379"], false)
        tryCompare(source, "loading", false)
        compare(source.entries.length, 0)
        entriesSpy.clear()
        source.refresh(false, 10, ["TLBStacksTestUnmatchedCategory81379"], false)
        tryCompare(source, "loading", false)
        compare(entriesSpy.count, 0)
    }
}
