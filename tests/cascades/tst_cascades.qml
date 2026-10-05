import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC2
import QtTest
import "../../package/contents/ui" as TLB

Item {
    width: 800
    height: 600
    QtObject {
        id: testBackend
        function folderAvailable(url) { return true }
        function fileIcon(url) { return "text-plain" }
        function openFile(url) { throw new Error("This test must not open files") }
    }
    TLB.FolderCascadeMenu {
        id: menu
        folderUrl: Qt.resolvedUrl("fixture")
        patterns: ["*.txt"]
        backend: testBackend
        iconSize: 22
        rowHeight: 40
        menuWidth: 220
        iconsOnly: false
    }
    Item { id: narrowAnchor; x: 10; y: 10; width: 70; height: 40 }
    Component {
        id: detachedFactory
        TLB.FolderCascadeMenu {
            folderUrl: Qt.resolvedUrl("fixture")
            patterns: ["*.txt"]
            backend: testBackend
            iconSize: 22
            rowHeight: 40
            menuWidth: 220
            iconsOnly: false
        }
    }
    TestCase {
        name: "CascadingFolders"
        when: windowShown
        function test_independent_window() {
            const anchor = narrowAnchor
            tryVerify(() => anchor.Window.window !== null)
            const popup = detachedFactory.createObject(null, {parent: anchor})
            try {
                popup.x = anchor.width - 1
                popup.y = 0
                popup.open()
                tryCompare(popup, "visible", true)
                tryVerify(() => popup.childMenus.length === 1)
                verify(popup.contentItem.Window.window !== anchor.Window.window,
                       "Submenu must have its own window, outside the parent overlay")
                const anchorPosition = anchor.mapToGlobal(0, 0)
                const popupPosition = popup.contentItem.mapToGlobal(0, 0)
                verify(popupPosition.x >= anchorPosition.x + anchor.width - 2,
                       "Submenu must open beside its row")
                mouseMove(popup.itemAt(1), 25, 20)
                tryVerify(() => popup.pointerInBranch())
            } finally {
                popup.close()
                popup.destroy()
            }
        }
        function test_hover_and_close() {
            compare(menu.childMenus.length, 0)
            menu.popup(parent, Qt.point(10, 10))
            tryCompare(menu, "visible", true)
            tryVerify(() => menu.childMenus.length === 1)
            compare(menu.count, 3) // folder, matching file, hidden status row
            const child = menu.childMenus[0]
            compare(child.childMenus.length, 0)
            mouseMove(menu.itemAt(0), 25, 20)
            tryCompare(child, "visible", true, 3000)
            tryVerify(() => child.childMenus.length === 1)
            mouseMove(child.itemAt(0), 25, 20)
            const grandchild = child.childMenus[0]
            tryCompare(grandchild, "visible", true, 3000)
            verify(menu.pointerInBranch())
            mouseMove(menu.itemAt(1), 25, 20)
            tryCompare(child, "visible", false, 3000)
            menu.close()
            tryCompare(menu, "visible", false)
            tryVerify(() => menu.childMenus.length === 0)
        }
    }
}
