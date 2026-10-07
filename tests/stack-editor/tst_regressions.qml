import QtQuick
import QtTest
import com.mattphilmon.tlbstacks
Rectangle {
    id: scene
    width: 600; height: 500
    StackSettingsEditor {
        id: editor
        anchors.fill: parent
        settings: ({menuSource: "applications", applications: [], applicationCategories: [], hoverDelay: 250, menuIconSize: 22})
        onSettingsEdited: changes => settings = Object.assign({}, settings, changes)
    }
    TestCase {
        name: "EditorReviewRegressions"
        when: windowShown
        function test_typed_hover_updates_before_focus_leaves() {
            findChild(editor, "tabs").currentIndex = 1
            wait(50)
            const spin = findChild(editor, "hoverDelayField")
            spin.contentItem.forceActiveFocus()
            keyClick(Qt.Key_A, Qt.ControlModifier)
            keyClick(Qt.Key_5); keyClick(Qt.Key_0)
            compare(editor.settings.hoverDelay, 50)
        }
        function test_long_category_pages_are_reachable() {
            findChild(editor, "tabs").currentIndex = 0
            editor.catalog = Array.from({length: 70}, (_, i) => ({desktopId: "app" + i,
                name: "App " + i, categories: ["Category " + i]}))
            for (const source of ["categories", "activity"]) {
                editor.setKind(source)
                wait(100)
                const scroll = findChild(editor, source === "categories" ? "categoryScroll" : "activityScroll")
                verify(scroll.height <= editor.height)
                verify(scroll.contentHeight > scroll.availableHeight)
                scroll.contentItem.contentY = scroll.contentHeight - scroll.availableHeight
                verify(scroll.contentItem.contentY > 0)
            }
        }
        function test_recent_options_are_compact_and_left_aligned() {
            findChild(editor, "tabs").currentIndex = 0
            editor.setKind("activity")
            wait(100)
            const options = findChild(editor, "activityOptions")
            const scroll = findChild(editor, "activityScroll")
            compare(options.columns, 2)
            verify(options.mapToItem(scroll, 0, 0).x < 2)
            verify(options.height < 180)
        }
        function test_member_icon_errors_visible_on_contents() {
            findChild(editor, "tabs").currentIndex = 0
            editor.iconPending = {id: 42, target: "test.desktop"}
            editor.handleIconResult(42, {ok: false, error: "Invalid image"})
            const error = findChild(editor, "iconErrorLabel")
            verify(error.visible)
            compare(error.text, "Invalid image")
        }
    }
}
