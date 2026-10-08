import QtQuick
import QtTest
import com.mattphilmon.tlbstacks

TestCase {
    name: "StackMemberReorder"
    when: windowShown
    visible: true
    width: 760; height: 560
    StackSettingsEditor {
        id: editor
        width: 760; height: 560
        onSettingsEdited: changes => settings = Object.assign({}, settings, changes)
    }
    SignalSpy { id: edits; target: editor; signalName: "settingsEdited" }
    readonly property string separator: "tlbstacks-separator:1"
    function init() {
        editor.settings = {menuSource: "applications", applications: ["first.desktop", separator, "last.desktop"],
            applicationIcons: {"first.desktop": "custom-icon"}}
        wait(30)
        findChild(editor, "memberList").positionViewAtBeginning()
        edits.clear()
    }
    function handle(index) {
        return findChild(findChild(editor, "memberList").itemAtIndex(index), "reorder-member-" + editor.settings.applications[index])
    }
    function test_drag_application_past_separator() {
        const first = handle(0), last = handle(2)
        const target = last.mapToItem(first, 12, last.height - 2)
        mousePress(first, 12, first.height / 2)
        mouseMove(first, target.x, target.y, 30)
        compare(edits.count, 0)
        mouseRelease(first, target.x, target.y)
        compare(edits.count, 1)
        compare(editor.settings.applications, [separator, "last.desktop", "first.desktop"])
        compare(editor.settings.applicationIcons["first.desktop"], "custom-icon")
    }
    function test_drag_separator_to_top() {
        const source = handle(1), first = handle(0)
        const target = first.mapToItem(source, 12, 2)
        mousePress(source, 12, source.height / 2)
        mouseMove(source, target.x, target.y, 30)
        mouseRelease(source, target.x, target.y)
        compare(editor.settings.applications, [separator, "first.desktop", "last.desktop"])
    }
    function test_cancel_outside_and_escape() {
        let source = handle(0)
        mousePress(source, 12, 10)
        mouseMove(source, -30, 80, 30)
        mouseRelease(source, -30, 80)
        compare(edits.count, 0)
        source = handle(0)
        mousePress(source, 12, 10)
        mouseMove(source, 12, 80, 30)
        verify(findChild(editor, "memberReorder").active)
        keyClick(Qt.Key_Escape)
        mouseRelease(source, 12, 80)
        compare(edits.count, 0)
    }
    function test_settings_switch_cancels_gesture() {
        const controller = findChild(editor, "memberReorder")
        controller.draggingId = "first.desktop"
        controller.boundary = 3
        editor.settings = Object.assign({}, editor.settings, {groupName: "Other stack"})
        verify(!controller.active)
        controller.finish()
        compare(edits.count, 0)
    }
    function test_invalid_and_adjacent_moves_do_not_emit() {
        editor.reorderMember("missing.desktop", 0)
        editor.reorderMember("first.desktop", -1)
        editor.reorderMember("first.desktop", 1)
        compare(edits.count, 0)
        editor.settings = Object.assign({}, editor.settings, {menuSource: "categories"})
        editor.reorderMember("first.desktop", 3)
        compare(edits.count, 0)
    }
}
