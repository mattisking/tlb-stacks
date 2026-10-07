import QtQuick
import QtTest
import "../../package-group/contents/ui" as Group
import "../../package-group/contents/ui/GroupItems.js" as Items
TestCase {
    name: "GroupStackEditor"
    Group.ConfigGeneral { id: editor; width: 800; height: 650 }
    function test_staged_edits() {
        editor.cfg_items = Items.encode(Items.addStack(Items.add([], "direct.desktop")))
        editor.selectedIndex = 1
        editor.updateStack({groupName: "Tools"})
        editor.addApplication("one.desktop")
        editor.addApplication("two.desktop")
        compare(editor.decoded.items[0].desktopId, "direct.desktop")
        compare(editor.selectedStack.settings.groupName, "Tools")
        compare(editor.selectedStack.settings.applications.length, 2)
        editor.changeMember(1, -1, false)
        compare(editor.selectedStack.settings.applications[0], "two.desktop")
        editor.changeMember(0, 0, true)
        compare(editor.selectedStack.settings.applications[0], "one.desktop")
        editor.selectedIndex = 0
        compare(editor.selectedStack, null)
    }
}
