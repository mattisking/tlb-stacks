import QtQuick
import QtTest
import com.mattphilmon.tlbstacks

Rectangle {
    id: scene
    width: 760; height: 560
    StackSettingsEditor {
        id: editor
        anchors.fill: parent
        settings: ({
            menuSource: "applications", groupName: "Dev", groupIcon: "applications-development",
            applications: ["code.desktop", "tlbstacks-separator:1"],
            applicationIcons: {}, iconsOnly: false, menuIconSize: 22, hoverDelay: 250,
            applicationCategories: [], activityOrder: "recent", activityLimit: 10,
            activityCurrent: false, folderUrl: "", folderFilters: "*" })
        // The harness plays the host: persist emitted partial changes back
        // into the settings the editor reads, exactly like the real hosts
        // (the group host's updateStack / the single host's applySettingsChanges,
        // fed back through the settings binding). The cumulative Contents tests
        // below need that loop to observe prior operations' state.
        onSettingsEdited: changes => settings = Object.assign({}, settings, changes)
        catalog: [
            {desktopId: "code.desktop", name: "Visual Studio Code", icon: "code", categories: ["Development"]},
            {desktopId: "dolphin.desktop", name: "Dolphin", icon: "system-file-manager", categories: ["FileManager"]},
            {desktopId: "konversation.desktop", name: "Konversation", icon: "konversation", categories: ["Network"]},
            {desktopId: "gone.desktop", name: "Gone", icon: "gone"}
        ]
    }
    SignalSpy { id: spy; target: editor; signalName: "settingsEdited" }
    TestCase {
        name: "StackSettingsEditorShell"
        when: windowShown
        function init() { spy.clear() }

        function test_kind_segments_emit_menuSource() {
            const folder = findChild(editor, "kind-folder")
            folder.clicked()
            compare(spy.count, 1)
            compare(spy.signalArguments[0][0], {menuSource: "folder"})
        }
        function test_appearance_fields_emit_partial_changes() {
            editor.setField("groupName", "Development")
            compare(spy.signalArguments[0][0], {groupName: "Development"})
            editor.setField("iconsOnly", true)
            compare(spy.signalArguments[1][0], {iconsOnly: true})
            editor.setField("menuIconSize", 32)
            compare(spy.signalArguments[2][0], {menuIconSize: 32})
            editor.setField("hoverDelay", 400)
            compare(spy.signalArguments[3][0], {hoverDelay: 400})
        }
        // Final-review I-1: a stored hoverDelay of 0 means immediate opening
        // and must show as 0, not fall back to 250. Also closes the deferred
        // "control bindings unasserted" gap: the value-facing controls must
        // reflect reassigned settings (the ruling-5 loop hosts rely on).
        function test_appearance_controls_reflect_settings_values() {
            editor.settings = Object.assign({}, editor.settings, {
                hoverDelay: 0, menuIconSize: 40, iconsOnly: true,
                activityLimit: 25, folderFilters: "*.txt;*.md",
                folderUrl: "file:///tmp/reflect"
            })
            compare(findChild(editor, "hoverDelayField").value, 0)
            compare(findChild(editor, "menuIconSizeField").value, 40)
            compare(findChild(editor, "iconsOnlyBox").checked, true)
            compare(findChild(editor, "activityLimitField").value, 25)
            compare(findChild(editor, "folderFiltersField").text, "*.txt;*.md")
            compare(findChild(editor, "folderUrlField").text, "file:///tmp/reflect")
        }
        // Final-review I-2: a failed manageIcon (bad/oversized image) must be
        // visible in the editor, cleared by the next success and by the next
        // Choose… call. Driven through handleIconResult directly — the
        // Connections handler just forwards to it, and tests never spawn
        // python or open the theme dialog (not headless-openable).
        function test_icon_operation_failure_shows_error() {
            // The error label lives on the Appearance page; `visible` reads
            // effective visibility, so make that tab current first.
            findChild(editor, "tabs").currentIndex = 1
            editor.iconPending = {id: 50, target: ""}
            editor.handleIconResult(50, {ok: false, error: "Image too large"})
            compare(editor.iconError, "Image too large")
            const label = findChild(editor, "iconErrorLabel")
            verify(label !== null)
            verify(label.visible)
            compare(label.text, "Image too large")
            // A stale request id must not clobber state.
            editor.iconPending = {id: 51, target: ""}
            editor.handleIconResult(999, {ok: false, error: "other"})
            compare(editor.iconError, "Image too large")
            // The next successful operation clears the error and still applies.
            editor.handleIconResult(51, {ok: true, icon: "theme-icon"})
            compare(editor.iconError, "")
            verify(!label.visible)
            compare(spy.count, 1)
            compare(spy.signalArguments[0][0], {groupIcon: "theme-icon"})
            // The next Choose… clears it too (file-dialog path).
            editor.iconPending = {id: 52, target: "code.desktop"}
            editor.handleIconResult(52, {ok: false, error: "Bad image"})
            compare(editor.iconError, "Bad image")
            editor.chooseIcon("", true)
            compare(editor.iconError, "")
            findChild(editor, "iconFileDialog").close()
        }
        function test_icon_result_applies_to_stack_or_member() {
            editor.applyIconResult("", "custom-icon")
            compare(spy.signalArguments[0][0].groupIcon, "custom-icon")
            editor.applyIconResult("code.desktop", "/images/code.png")
            compare(spy.signalArguments[1][0].applicationIcons["code.desktop"], "/images/code.png")
            editor.applyIconResult("code.desktop", "")
            compare(spy.signalArguments[2][0].applicationIcons["code.desktop"], undefined)
        }
        function test_icon_reset_uses_default() {
            editor.applyIconResult("", "")
            compare(spy.signalArguments[0][0].groupIcon, "applications-all")
        }
    }

    SignalSpy { id: spy2; target: editor; signalName: "settingsEdited" }
    TestCase {
        name: "StackSettingsEditorContents"
        when: windowShown
        function init() { spy2.clear() }

        // qmltestrunner executes test functions in alphabetical order, not
        // declaration order; the numeric prefixes keep the narrative order
        // the expectations are written against (each test builds on the
        // persisted state the previous one left in `editor.settings`).
        function test_01_member_add_rejects_duplicates() {
            editor.addMember("code.desktop")
            compare(spy2.count, 0)   // already a member
            editor.addMember("dolphin.desktop")
            const apps = spy2.signalArguments[0][0].applications
            compare(apps, ["code.desktop", "tlbstacks-separator:1", "dolphin.desktop"])
        }
        function test_02_member_move_remove_and_separator_rename() {
            editor.moveMember(2, -1)   // dolphin above separator
            compare(spy2.signalArguments[0][0].applications,
                ["code.desktop", "dolphin.desktop", "tlbstacks-separator:1"])
            editor.moveMember(0, -5)   // out of range: no-op (emits nothing)
            editor.removeMember(0)
            compare(spy2.signalArguments[1][0].applications, ["dolphin.desktop", "tlbstacks-separator:1"])
            editor.renameSeparator("tlbstacks-separator:1", "IDEs : Tools")
            compare(spy2.signalArguments[2][0].applications, ["dolphin.desktop", "tlbstacks-separator:1:IDEs : Tools"])
        }
        function test_03_add_separator_finds_free_number() {
            editor.addSeparator()
            compare(spy2.signalArguments[0][0].applications[2], "tlbstacks-separator:2")
        }
        function test_04_unavailable_member_names_fall_back() {
            compare(editor.memberName("gone.desktop"), "Gone")
            const fallback = String(editor.memberName("not-installed.desktop"))
            verify(fallback.indexOf("not-installed.desktop") >= 0)   // id stays visible
            verify(fallback.length > "not-installed.desktop".length) // wrapped in fallback text
        }
        function test_05_category_toggle_emits_next_array() {
            editor.setKind("categories")
            editor.toggleCategory("Development", true)
            compare(spy2.signalArguments[1][0].applicationCategories, ["Development"])
            editor.toggleCategory("Network", true)
            compare(spy2.signalArguments[2][0].applicationCategories, ["Development", "Network"])
            editor.toggleCategory("Development", false)
            compare(spy2.signalArguments[3][0].applicationCategories, ["Network"])
        }
        function test_06_folder_and_activity_fields() {
            editor.setField("folderUrl", "file:///home/matt/Documents")
            compare(spy2.signalArguments[0][0].folderUrl, "file:///home/matt/Documents")
            editor.setField("folderFilters", "*.pdf;*.docx")
            compare(spy2.signalArguments[1][0].folderFilters, "*.pdf;*.docx")
            editor.setField("activityOrder", "frequent")
            compare(spy2.signalArguments[2][0].activityOrder, "frequent")
            editor.setField("activityLimit", 20)
            compare(spy2.signalArguments[3][0].activityLimit, 20)
            editor.setField("activityCurrent", true)
            compare(spy2.signalArguments[4][0].activityCurrent, true)
        }
        // User feedback: the categories selection's effect was invisible —
        // "It doesn't show me the applications I chose based on the
        // categories I selected". The page must carry a read-only
        // matching-applications preview (objectName "matchingList") whose
        // count tracks the selection. test_05 left ["Network"] selected and
        // the categories page current.
        function test_07_matching_preview_tracks_selection() {
            editor.toggleCategory("Development", true)
            const list = findChild(editor, "matchingList")
            verify(list !== null)
            compare(list.count, 2)   // Visual Studio Code (Development) + Konversation (Network)
            editor.toggleCategory("Network", false)
            editor.toggleCategory("Development", false)
            compare(list.count, 0)
        }
        // Regression (user desktop report): the wrapped chip area and the
        // matching preview rendered on top of each other — the preview
        // covered roughly half the chips. Geometry guard: at fixed sizes,
        // with enough categories to force multi-row wrapping, the chip
        // area's reserved cell must fit the wrapped content and the preview
        // must start below that content — on the categories page (tight
        // squeeze regime and comfortable width) and on the activity page.
        function test_08_geometry_chips_and_preview_do_not_overlap() {
            editor.setKind("categories")
            editor.catalog = Array.from({length: 16}, (unused, i) => ({
                desktopId: "geom" + i + ".desktop", name: "Geometry app " + i,
                icon: "x", categories: ["Category " + (i + 1)]}))
            // Narrow and short: label + wrapped chips + preview minimum
            // cannot all fit — the squeeze regime that produced the
            // reported overlap.
            scene.width = 320; scene.height = 420
            wait(80)
            verifyNoChipPreviewOverlap()
            // Comfortable width: same invariants must hold.
            scene.width = 760; scene.height = 560
            wait(80)
            verifyNoChipPreviewOverlap()
            // Activity page: the same components under the options form.
            editor.setKind("activity")
            scene.width = 760; scene.height = 700
            wait(80)
            verifyNoChipPreviewOverlap()
            // Restore the shared scene and the page for later test cases.
            scene.width = 760; scene.height = 560
            editor.setKind("categories")
            wait(80)
        }
        function verifyNoChipPreviewOverlap() {
            const flow = findVisibleNamed(editor, "chipFlow")
            verify(flow !== null)
            // Multi-row wrap actually happened — a single-row pass could
            // hide the bug.
            const aChip = findVisibleNamed(editor, "chip-Category 1")
            verify(aChip !== null)
            verify(flow.implicitHeight > aChip.height * 1.5)
            // The reserved cell fits the wrapped chips…
            verify(flow.height + 0.5 >= flow.implicitHeight)
            // …and the preview starts below the chip content, not over it.
            const preview = findVisibleNamed(editor, "matchingPreview")
            verify(preview !== null)
            const flowTop = flow.mapToItem(editor, 0, 0).y
            verify(preview.mapToItem(editor, 0, 0).y + 0.5 >= flowTop + flow.implicitHeight)
            verify(flow.height > 0)
            verify(preview.height > 0)
        }
        // Both category-filter pages instantiate the shared chip bar and
        // preview, so their objectNames exist twice; StackLayout hides the
        // non-current page, and only the current page's instance is
        // effectively visible. (Dead delegates from model resets are
        // unparented and never collected.)
        function findVisibleNamed(parentItem, name) {
            const found = []
            collectNamed(parentItem, name, found)
            for (let i = 0; i < found.length; i++) {
                if (isEffectivelyVisible(found[i], parentItem)) return found[i]
            }
            return null
        }
        function collectNamed(item, name, acc) {
            if (item.objectName === name) acc.push(item)
            const kids = item.children
            for (let i = 0; i < kids.length; i++) collectNamed(kids[i], name, acc)
        }
        function isEffectivelyVisible(item, stopAt) {
            let current = item
            while (current && current !== stopAt) {
                if (!current.visible) return false
                current = current.parent
            }
            return true
        }
    }
}
