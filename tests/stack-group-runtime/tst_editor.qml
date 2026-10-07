import QtQuick
import QtTest
import "../../package-group/contents/ui" as Group
import "../../package-group/contents/ui/GroupItems.js" as Items
TestCase {
    name: "GroupStackEditor"
    Group.ConfigGeneral { id: editor; width: 800; height: 650 }
    function test_launcher_appearance_is_staged_and_targets_identity() {
        editor.cfg_items = Items.encode(Items.add(Items.add([], "first.desktop"), "second.desktop"))
        editor.selectedIndex = 0
        const id = editor.selectedItem.id
        editor.updateLauncherAppearance(id, {label: "Custom", icon: "utilities-terminal"})
        compare(JSON.parse(editor.cfg_items).version, 4)
        compare(editor.selectedItemName, "Custom")
        editor.pendingProfile = {id: 91, action: "manageIcon", targetId: id}
        editor.selectedIndex = 1
        editor.finishProfile(91, {ok: true, icon: "custom-icon"})
        compare(editor.decoded.items[0].icon, "custom-icon")
        verify(!editor.selectedItem.icon)
        editor.updateLauncherAppearance(id, {label: "", icon: ""})
        compare(JSON.parse(editor.cfg_items).version, 1)
        compare(editor.decoded.items[0].desktopId, "first.desktop")
    }
    // Final-review I-3: the default group name is "" (cfg_groupNameDefault),
    // so the breadcrumb must fall back to the tree header's "Group" label in
    // both branches, and StyledText must never receive imported names raw —
    // an imported "<img src=…>" name would render as a remotely-fetchable
    // image tag. The test env is untranslated, so i18n("Group") is "Group".
    function test_breadcrumb_fallback_and_escaping() {
        editor.cfg_groupName = ""
        editor.cfg_items = Items.encode(Items.addStack([]))
        editor.selectedIndex = 0
        const crumb = findChild(editor, "breadcrumb")
        verify(crumb !== null)
        // Empty group name still labels the link (and the plain branch too).
        verify(crumb.text.indexOf("<a href='group'>Group</a>") === 0)
        // A stack name containing markup renders escaped.
        editor.updateStack({groupName: "<img src='x'>"})
        verify(crumb.text.indexOf("&lt;img") >= 0)
        verify(crumb.text.indexOf("<img src='x'>") < 0)
        // The group-name link is escaped as well.
        editor.cfg_groupName = "A&B <b>"
        verify(crumb.text.indexOf("A&amp;B") >= 0)
        verify(crumb.text.indexOf("&lt;b&gt;") >= 0)
        verify(crumb.text.indexOf("<b>") < 0)
        // Back on the group page the plain branch shows the fallback, too.
        editor.cfg_groupName = ""
        editor.selectedIndex = -1
        compare(crumb.text, "Group")
    }
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
    // Adapted for the shared editor: the category list now lives inside the
    // embedded StackSettingsEditor as a CategoryChipBar (chipFilter + chips);
    // per-bar filter behavior is covered by tests/stack-editor/tst_chipbar.qml.
    // This test keeps its purpose: filtering is visual-only and hidden
    // selections survive source switches through the host's persistence.
    // Chips are located through the bar's visual children: Repeater model
    // resets leave removed delegates unparented-but-findable, so findChild
    // can return a dead object after the filter narrows the model.
    function findLive(item, name) {
        if (item.objectName === name) return item
        const kids = item.children
        for (let i = 0; i < kids.length; i++) {
            const found = findLive(kids[i], name)
            if (found) return found
        }
        return null
    }
    function test_category_filter_preserves_hidden_selections() {
        editor.cfg_items = Items.encode(Items.addStack([]))
        editor.selectedIndex = 0
        editor.catalog = [{desktopId: "test", name: "Test", categories: ["Development", "Graphics"]}]
        editor.updateStack({menuSource: "categories", applicationCategories: ["Graphics"]})
        const search = findChild(editor, "chipFilter")
        verify(search !== null)
        search.text = "DEVEL"
        compare(editor.selectedStack.settings.applicationCategories, ["Graphics"])
        const chip = findLive(search.parent, "chip-Development")
        verify(chip !== null)
        chip.clicked()
        compare(editor.selectedStack.settings.applicationCategories, ["Graphics", "Development"])
        editor.updateStack({menuSource: "activity"})
        compare(editor.selectedStack.settings.applicationCategories, ["Graphics", "Development"])
        editor.updateStack({menuSource: "categories"})
        search.text = ""
        compare(editor.selectedStack.settings.applicationCategories, ["Graphics", "Development"])
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
        // changeMember moved into the shared editor (covered by
        // tests/stack-editor/tst_stacksettings.qml test_02); the same reorders
        // run through the retained updateStack so staging stays covered.
        editor.updateStack({applications: ["two.desktop", "one.desktop"]})
        compare(editor.selectedStack.settings.applications[0], "two.desktop")
        editor.updateStack({applications: ["one.desktop"]})
        compare(editor.selectedStack.settings.applications[0], "one.desktop")
        editor.selectedIndex = 0
        compare(editor.selectedStack, null)
    }
    function test_source_switch_keeps_settings_roundtrip() {
        editor.cfg_items = Items.encode(Items.addStack([]))
        const id = editor.decoded.items[0].id
        editor.selectedIndex = 0
        editor.updateStack({menuSource: "folder", folderUrl: "file:///tmp", folderFilters: "*.txt"})
        editor.updateStack({menuSource: "applications", applications: ["one.desktop"]})
        editor.updateStack({menuSource: "folder"})
        const settings = editor.decoded.items[0].settings
        compare(settings.folderUrl, "file:///tmp")
        compare(settings.folderFilters, "*.txt")
        compare(settings.applications, ["one.desktop"])
        verify(!Items.decode(editor.cfg_items).error)
    }
    function test_replace_launcher_swaps_app() {
        editor.cfg_items = Items.encode(Items.add(Items.add([], "one.desktop"), "two.desktop"))
        editor.selectedIndex = 0
        editor.replaceLauncherApp("three.desktop")
        compare(editor.decoded.items[0].desktopId, "three.desktop")
        editor.replaceLauncherApp("two.desktop")   // duplicate → no-op
        compare(editor.decoded.items[0].desktopId, "three.desktop")
    }
    function test_forward_version_config_stays_inert() {
        editor.cfg_items = '{"version":99,"items":[]}'
        verify(editor.decoded.error)
        const previous = editor.cfg_items
        editor.selectedIndex = 0
        editor.updateStack({groupName: "Must not apply"})
        compare(editor.cfg_items, previous)
        editor.replaceLauncherApp("one.desktop")
        compare(editor.cfg_items, previous)
        editor.cfg_items = Items.encode(Items.add([], "one.desktop"))
        verify(!editor.decoded.error)
    }
    // Ruling 5 (binding lifetime) for the group host's selection switch:
    // selecting another stack reassigns the shared editor's settings binding.
    // Select A, edit, select B, edit, return to A: the control-facing kind
    // segment must reflect A's persisted settings after both reassignments.
    function test_selection_switch_round_trip() {
        editor.cfg_items = Items.encode(Items.addStack(Items.addStack([])))
        editor.selectedIndex = 0
        editor.updateStack({menuSource: "folder", folderUrl: "file:///tmp", groupName: "Alpha"})
        editor.selectedIndex = 1
        editor.updateStack({groupName: "Beta"})
        editor.selectedIndex = 0
        compare(editor.decoded.items[0].settings.groupName, "Alpha")
        compare(editor.decoded.items[0].settings.folderUrl, "file:///tmp")
        compare(editor.decoded.items[1].settings.groupName, "Beta")
        const folderSegment = findChild(editor, "kind-folder")
        const appsSegment = findChild(editor, "kind-applications")
        verify(folderSegment !== null && appsSegment !== null)
        compare(folderSegment.checked, true)
        editor.selectedIndex = 1
        compare(folderSegment.checked, false)
        compare(appsSegment.checked, true)
        editor.selectedIndex = 0
        compare(folderSegment.checked, true)
    }
}
