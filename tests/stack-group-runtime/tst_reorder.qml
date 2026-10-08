import QtQuick
import QtTest
import "../../package-group/contents/ui" as Group
import "../../package-group/contents/ui/GroupItems.js" as Items

TestCase {
    name: "GroupTreeReorder"
    when: windowShown
    visible: true
    width: 1000
    height: 750
    Group.ConfigGeneral { id: editor; width: 1000; height: 750 }
    property string originalConfig
    property var original
    function init() {
        original = Items.add(Items.addStack(Items.add([], "first.desktop")), "last.desktop")
        original = Items.updateStack(original, original[1].id, {applications: ["member.desktop"]})
        editor.cfg_items = Items.encode(original)
        originalConfig = editor.cfg_items
        original = editor.decoded.items
        editor.expandedIds = ({})
        editor.selectedIndex = 1
        editor.cancelItemDrag()
        wait(30)
        findChild(editor, "itemTree").positionViewAtBeginning()
        wait(10)
    }
    function handle(index) {
        const tree = findChild(editor, "itemTree")
        return findChild(tree.itemAtIndex(index), "reorder-" + editor.decoded.items[index].id)
    }
    function test_drag_stages_until_release() {
        const first = handle(0)
        const last = handle(2)
        verify(first && last)
        const target = last.mapToItem(first, last.width / 2, last.height - 3)
        mousePress(first, first.width / 2, first.height / 2)
        verify(first.pressed, "handle pressed " + first.mapToItem(null, 0, 0) + " size " + first.width + "," + first.height)
        mouseMove(first, target.x, target.y, 30)
        compare(editor.draggingItemId, original[0].id)
        compare(editor.dropBoundary, 3)
        compare(editor.cfg_items, originalConfig)
        mouseRelease(first, target.x, target.y)
        compare(editor.decoded.items.map(item => item.id).join(), [original[1].id, original[2].id, original[0].id].join())
        compare(editor.selectedItem.id, original[1].id)
        compare(editor.draggingItemId, "")
    }
    function test_outside_release_and_escape_cancel() {
        let first = handle(0)
        mousePress(first, 10, 10)
        mouseMove(first, -30, 90, 30)
        mouseRelease(first, -30, 90)
        compare(editor.cfg_items, originalConfig)
        first = handle(0)
        mousePress(first, 10, 10)
        mouseMove(first, 10, 100, 30)
        verify(editor.draggingItemId.length > 0)
        keyClick(Qt.Key_Escape)
        compare(editor.draggingItemId, "")
        mouseRelease(first, 10, 100)
        compare(editor.cfg_items, originalConfig)
    }
    function test_drag_up_across_expanded_stack() {
        editor.toggleExpanded(original[1].id)
        wait(30)
        const last = handle(2)
        const first = handle(0)
        const target = first.mapToItem(last, 12, 2)
        mousePress(last, 12, last.height / 2)
        mouseMove(last, target.x, target.y, 30)
        compare(editor.dropBoundary, 0)
        mouseRelease(last, target.x, target.y)
        compare(editor.decoded.items[0].id, original[2].id)
        verify(editor.expandedIds[original[1].id])
    }
    function test_edge_scroll_keeps_drag_alive() {
        let items = []
        for (let i = 0; i < 30; ++i) items = Items.add(items, "app-" + i + ".desktop")
        editor.cfg_items = Items.encode(items)
        editor.selectedIndex = -1
        wait(30)
        const tree = findChild(editor, "itemTree")
        tree.positionViewAtBeginning()
        const first = handle(0)
        const initialY = tree.contentY
        const target = tree.mapToItem(first, 12, tree.height - 4)
        mousePress(first, 12, first.height / 2)
        mouseMove(first, target.x, target.y, 30)
        tryVerify(() => tree.contentY > initialY + 100, 1500)
        compare(editor.draggingItemId, items[0].id)
        keyClick(Qt.Key_Escape)
        mouseRelease(first, target.x, target.y)
        compare(editor.decoded.items[0].id, items[0].id)
    }
    function test_move_preserves_expansion_member_and_settings() {
        editor.toggleExpanded(original[1].id)
        editor.selectMember(1, "member.desktop")
        editor.reorderItem(original[1].id, 0)
        compare(editor.selectedIndex, 0)
        verify(editor.memberSelected)
        verify(editor.expandedIds[original[1].id])
        compare(JSON.stringify(editor.selectedItem), JSON.stringify(original[1]))
        const before = editor.cfg_items
        editor.reorderItem(original[1].id, 1) // adjacent boundary is a no-op
        editor.reorderItem("missing", 2)
        editor.reorderItem(original[1].id, -1)
        compare(editor.cfg_items, before)
    }
}
