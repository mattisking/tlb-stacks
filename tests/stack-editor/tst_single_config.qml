import QtQuick
import QtTest
import "../../package/contents/ui" as Single

Rectangle {
    width: 760; height: 560
    Single.ConfigGeneral { id: page; anchors.fill: parent }

    TestCase {
        name: "SingleHostSharedEditor"
        when: windowShown

        // Depth-first search for the first item matching `match`. ObjectNames
        // cover the kind segments and the member list; the Appearance name
        // field has none, so it is reached by its unique placeholder text.
        function findFirstItem(parentItem, match) {
            if (match(parentItem)) return parentItem
            const children = parentItem.children
            for (let i = 0; i < children.length; ++i) {
                const found = findFirstItem(children[i], match)
                if (found !== null) return found
            }
            return null
        }

        function test_synthesized_settings_match_cfg() {
            page.cfg_groupName = "Work"
            page.cfg_menuSource = "activity"
            page.cfg_applications = ["a.desktop", "tlbstacks-separator:1:Tools"]
            compare(page.stackSettings.groupName, "Work")
            compare(page.stackSettings.menuSource, "activity")
            compare(page.stackSettings.applications, ["a.desktop", "tlbstacks-separator:1:Tools"])
        }

        function test_editor_changes_apply_to_cfg() {
            page.applySettingsChanges({groupName: "Dev", iconsOnly: true, menuIconSize: 30})
            compare(page.cfg_groupName, "Dev")
            compare(page.cfg_iconsOnly, true)
            compare(page.cfg_menuIconSize, 30)
            page.applySettingsChanges({applications: ["x.desktop"], applicationIcons: {"x.desktop": "/img/x.png"}})
            compare(page.cfg_applications, ["x.desktop"])
            compare(page.cfg_applicationIcons, '{"x.desktop":"/img/x.png"}')
        }

        function test_import_staging_still_works() {
            page.pendingProfile = {id: 7, action: "import"}
            page.finishProfile(7, {ok: true, settings: {
                groupName: "Imported", groupIcon: "applications-all", iconsOnly: false,
                menuIconSize: 22, hoverDelay: 250, applications: ["i.desktop"],
                applicationIcons: {}, menuSource: "applications", activityOrder: "recent",
                activityLimit: 10, activityCurrent: false, applicationCategories: [],
                folderUrl: "", folderFilters: "*"}})
            compare(page.cfg_groupName, "Imported")
            compare(page.cfg_applications, ["i.desktop"])
        }

        // Ruling 5 (binding lifetime): every persisted edit re-synthesizes
        // stackSettings, so the editor's `settings` is reassigned under live
        // controls. After several changes — the last one a real typed edit —
        // the controls and the synthesized settings must both show the new
        // state, and an external reassignment (import) must still reach the
        // name field the user just typed into.
        function test_settings_reassignment_round_trip() {
            page.applySettingsChanges({menuSource: "folder", groupName: "Round"})
            compare(findChild(page, "kind-folder").checked, true)
            page.applySettingsChanges({menuSource: "applications", applications: ["a.desktop", "b.desktop"]})
            compare(page.stackSettings.applications, ["a.desktop", "b.desktop"])
            compare(findChild(page, "memberList").count, 2)

            const appearanceTab = findFirstItem(page, item => item.text === "Appearance")
            verify(appearanceTab !== null)
            mouseClick(appearanceTab)
            const nameField = findFirstItem(page, item => item.placeholderText === "Stack name")
            verify(nameField !== null)
            nameField.forceActiveFocus()
            // The field still shows the persisted "Round" (the binding picked
            // up the earlier reassigned settings), so typing appends to it —
            // and the whole loop (edit → settingsEdited → applySettingsChanges
            // → cfg_* → stackSettings) must carry the combined text back out.
            for (const character of "dev") keyClick(character)
            compare(page.stackSettings.groupName, "Rounddev")

            page.pendingProfile = {id: 9, action: "import"}
            page.finishProfile(9, {ok: true, settings: {
                groupName: "Imported", groupIcon: "applications-all", iconsOnly: false,
                menuIconSize: 22, hoverDelay: 250, applications: ["i.desktop"],
                applicationIcons: {}, menuSource: "applications", activityOrder: "recent",
                activityLimit: 10, activityCurrent: false, applicationCategories: [],
                folderUrl: "", folderFilters: "*"}})
            compare(page.stackSettings.groupName, "Imported")
            compare(nameField.text, "Imported")
        }
        // Final-review I-1 end to end: cfg_hoverDelay 0 is a stored value, so
        // the synthesized settings must carry it through to the editor's
        // spinbox as 0 (previously `|| 250` displayed the default instead).
        function test_zero_hover_delay_reflects_in_editor() {
            page.cfg_hoverDelay = 0
            page.cfg_menuIconSize = 30
            const delay = findChild(page, "hoverDelayField")
            verify(delay !== null)
            compare(delay.value, 0)
            const size = findChild(page, "menuIconSizeField")
            verify(size !== null)
            compare(size.value, 30)
        }
    }
}
