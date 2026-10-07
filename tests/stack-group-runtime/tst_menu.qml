import QtQuick
import QtTest
import "../../package/contents/ui" as TLB
TestCase {
    name: "SharedApplicationMenu"
    when: windowShown
    width: 280; height: 240
    QtObject {
        id: backend
        function themeIconAvailable(name) { return true }
        function activateEntry(entry) { return true }
        function showEntryContextMenu(anchor, entry) {}
    }
    TLB.ApplicationMenu {
        id: menu
        width: 260; height: 200
        launcher: backend
        entries: [
            {id: "a", name: "Alpha", icon: "folder", available: true, isSeparator: false, actions: []},
            {id: "s", name: "", icon: "", available: true, isSeparator: true, actions: []},
            {id: "b", name: "Beta", icon: "folder", available: true, isSeparator: false, actions: []}
        ]
    }
    function test_navigation_and_reset() {
        menu.resetSelection()
        menu.moveApplicationSelection(1)
        compare(menu.selectedApplication, 0)
        menu.moveApplicationSelection(1)
        compare(menu.selectedApplication, 2)
        menu.moveApplicationSelection(1)
        compare(menu.selectedApplication, 0)
        menu.resetSelection()
        compare(menu.selectedApplication, -1)
    }
}
