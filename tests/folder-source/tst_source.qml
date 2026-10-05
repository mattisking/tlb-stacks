import QtQuick
import QtTest
import com.mattphilmon.truelaunchbar
Item {
    FolderSource {
        id: source
        folder: Qt.resolvedUrl("../cascades/fixture")
        filters: ["*.txt"]
        active: true
    }
    TestCase {
        name: "FolderSourceBinding"
        when: windowShown
        function test_entriesReachQml() {
            tryCompare(source, "loading", false)
            tryCompare(source, "available", true)
            compare(source.entries.length, 2)
            compare(source.entries[0].hasChildren, true)
            compare(source.entries[0].name, "child")
            compare(source.entries[1].action, "openFile")
            compare(source.entries[1].actions.length, 1)
            compare(source.entries[1].actions[0], "moveToTrash")
        }
    }
}
