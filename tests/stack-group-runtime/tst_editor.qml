import QtQuick
import QtTest
import "../../package-group/contents/ui" as Group
import "../../package-group/contents/ui/GroupItems.js" as Items
TestCase {
    name: "GroupStackEditor"
    Group.ConfigGeneral { id: editor; width: 800; height: 650 }
    function test_import_results_are_staged_and_errors_preserve_editor() {
        editor.cfg_items = Items.encode(Items.add([], "existing.desktop"))
        const stack = Items.addStack([])[0]
        editor.pendingProfile = {id: 41, action: "importGroup"}
        editor.finishProfile(41, {ok: true, kind: "stack", settings: stack.settings})
        compare(editor.decoded.items.length, 2)
        compare(editor.decoded.items[0].desktopId, "existing.desktop")
        editor.pendingProfile = {id: 42, action: "importGroup"}
        editor.finishProfile(42, {ok: true, kind: "group", group: {groupName: "Imported", items: [stack]}})
        compare(editor.cfg_groupName, "Imported")
        compare(editor.decoded.items.length, 1)
        const previous = editor.cfg_items
        editor.pendingProfile = {id: 43, action: "importGroup"}
        editor.finishProfile(43, {ok: false, error: "Bad archive"})
        compare(editor.cfg_items, previous)
        compare(editor.profileMessage, "Bad archive")
    }
    function test_category_filter_preserves_hidden_selections() {
        editor.cfg_items = Items.encode(Items.addStack([]))
        editor.selectedIndex = 0
        editor.catalog = [{desktopId: "test", name: "Test", categories: ["Development", "Graphics"]}]
        editor.updateStack({menuSource: "categories", applicationCategories: ["Graphics"]})
        const search = findChild(editor, "categorySearch")
        const list = findChild(editor, "categoryList")
        verify(search !== null && list !== null)
        search.text = "DEVEL"
        compare(list.model.length, 1)
        compare(list.model[0], "Development")
        compare(editor.selectedStack.settings.applicationCategories[0], "Graphics")
        editor.updateStack({menuSource: "activity"})
        compare(list.model.length, 1)
        search.text = ""
        compare(list.model.length, 2)
        compare(editor.selectedStack.settings.applicationCategories[0], "Graphics")
    }
    function test_source_controls_preserve_other_settings() {
        editor.cfg_items = Items.encode(Items.addStack([]))
        editor.selectedIndex = 0
        editor.addApplication("editor.desktop")
        editor.updateStack({menuSource: "categories", applicationCategories: ["Development"]})
        compare(editor.selectedSource, "categories")
        editor.updateStack({menuSource: "activity", activityOrder: "frequent", activityLimit: 6})
        compare(editor.selectedStack.settings.activityLimit, 6)
        editor.updateStack({menuSource: "folder", folderUrl: "file:///tmp", folderFilters: "*.pdf"})
        compare(editor.selectedSource, "folder")
        editor.updateStack({menuSource: "applications"})
        compare(editor.selectedStack.settings.applications[0], "editor.desktop")
        compare(editor.selectedStack.settings.applicationCategories[0], "Development")
        compare(editor.selectedStack.settings.folderFilters, "*.pdf")
    }
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
