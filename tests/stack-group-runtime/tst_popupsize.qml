import QtQuick
import QtTest
import "../../package-group/contents/ui" as Group
TestCase {
    name: "GroupPopupSize"
    QtObject {
        id: backend
        function themeIconAvailable(name) { return true }
        function activateEntry(entry) { return true }
        function showEntryContextMenu(anchor, entry) {}
    }
    Group.GroupStackContent { id: content; launcher: backend }
    function apps(count) {
        return Array.from({length: count}, (_, i) => ({id: "app" + i,
            name: "Application " + i, icon: "folder", available: true,
            isSeparator: false, actions: []}))
    }
    function test_actual_height_tracks_stack_switching() {
        content.entries = apps(10)
        compare(content.height, 400)
        content.entries = apps(2)
        compare(content.height, 80)
        content.entries = apps(20)
        compare(content.height, 480)
        content.entries = []
        verify(content.height >= 40)
    }
    function test_icons_only_and_size() {
        content.iconsOnly = true
        content.iconSize = 48
        content.entries = apps(4)
        compare(content.width, 64)
        compare(content.height, 256)
    }
}
