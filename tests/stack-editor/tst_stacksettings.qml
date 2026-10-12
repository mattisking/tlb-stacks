import QtQuick
import QtTest
import com.mattphilmon.tlbstacks
// Provides the global i18n() used by the product QML (KLocalizedQmlContext);
// the test harness has no Plasma shell to install it.
import org.kde.plasma.core as PlasmaCore

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
        // User request: all four kind segments carry a border at all times
        // (the active one additionally keeps its highlight). Each segment
        // must have the 1px overlay, the checked derivation from menuSource
        // must be untouched, and a real mouse click must still reach the
        // button through the overlay (plain Rectangles accept no mouse
        // buttons, but this guards it).
        function test_kind_segments_have_persistent_borders() {
            for (const kind of editor.kinds) {
                const segment = findChild(editor, "kind-" + kind.id)
                verify(segment !== null)
                const border = findChild(segment, "kindBorder")
                verify(border !== null)
                compare(border.border.width, 1)
                verify(border.visible)
                compare(segment.checked, editor.menuSource === kind.id)
            }
            mouseClick(findChild(editor, "kind-activity"))
            compare(spy.count, 1)
            compare(spy.signalArguments[0][0], {menuSource: "activity"})
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
            compare(findChild(editor, "folderUrlField").text, "/tmp/reflect")
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

    // ---- nested category filter (live-verification follow-up)
    // A kwin-mcp live render of the shared editor left one open question:
    // typing "game" into the category filter visibly changed the field, yet
    // the chip cloud did not narrow — while tst_chipbar.qml's filter test
    // on a STANDALONE bar passes. The difference between the two contexts
    // is nesting: in the real editor the bar sits under StackSettingsEditor
    // → Categories page (QQC2.ScrollView) → ColumnLayout → CategoryChipBar,
    // and BOTH the Categories and the Activity pages instantiate a bar
    // (identical "chipFilter" objectName on both fields). This instance
    // drives the filter through exactly that real nesting; the standalone
    // test cannot, because it never leaves the component's own scope.
    StackSettingsEditor {
        id: nestedEditor
        // Just outside the window (the scene is at most 760 wide) but fully
        // visible as far as the property chain is concerned — off-window
        // items keep visible: true — so delegate `.visible` assertions read
        // exactly like the live editor's, while no geometry ever overlaps
        // the shared `editor` above (whose tests click by coordinates).
        x: 800
        width: 760; height: 560
        settings: ({menuSource: "categories", applicationCategories: []})
        // The same host-persistence loop the shared editor and the real
        // hosts play: toggleCategory's emitted change must be fed back into
        // `settings` for the bar's `selected` binding to observe it.
        onSettingsEdited: changes => settings = Object.assign({}, settings, changes)
        catalog: [
            {desktopId: "code.desktop", name: "Visual Studio Code", icon: "code", categories: ["Development"]},
            {desktopId: "kpat.desktop", name: "Patience", icon: "games-card", categories: ["ActionGame", "ArcadeGame"]},
            {desktopId: "juk.desktop", name: "JuK", icon: "audio-player", categories: ["Audio"]}
        ]
    }
    TestCase {
        name: "StackSettingsEditorNestedFilter"
        when: windowShown

        // Decides the live question headlessly: if this passes, the filter
        // binding is proven through the real editor nesting and the live
        // anomaly was an input-tool artifact; if it fails, the nesting
        // broke the binding and this failure IS the bug report.
        function test_filter_narrows_chips_through_real_nesting() {
            // Select a non-matching category first, through the public API:
            // selected chips must survive any filter text (the bar's core
            // invariant), and the selection must persist via the host loop.
            nestedEditor.toggleCategory("Development", true)
            compare(nestedEditor.settings.applicationCategories, ["Development"])
            // Disambiguation: both category-filter pages carry a
            // "chipFilter" field. findChild returns the first declared —
            // the Categories page's, because the contents pages are
            // declared applications, folder, categories, activity — but
            // rather than trusting traversal order, each page's field is
            // picked by its ancestor scroll view ("categoryScroll" and
            // "activityScroll" are page-unique objectNames), and the
            // first-declared fact is asserted on top so it stays documented.
            const categoryField = filterFieldOf("categoryScroll")
            const activityField = filterFieldOf("activityScroll")
            verify(categoryField !== activityField)
            verify(findChild(nestedEditor, "chipFilter") === categoryField)
            // The bar that owns the field (its Repeater model binds to the
            // field's text). Delegate presence is asserted per-bar, not per-
            // editor: the OTHER page's bar lists the same category names
            // with its own unfiltered model, so an editor-wide lookup would
            // find its chips no matter what this bar's filter hides.
            const bar = chipBarOf(categoryField)
            const activityBar = chipBarOf(activityField)
            // Baseline: with no filter text every chip is present.
            verify(findLive(bar, "chip-Development") !== null)
            verify(findLive(bar, "chip-ActionGame") !== null)
            verify(findLive(bar, "chip-Audio") !== null)

            categoryField.text = "game"

            // Unselected non-matching chip: GONE from this bar (the Repeater
            // destroyed the delegate — narrowed, not hidden), mirroring
            // tst_chipbar's assertions.
            verify(findLive(bar, "chip-Audio") === null)
            // Unselected matching chip: present and visible through the
            // whole nesting chain (the categories page is current).
            const game = findLive(bar, "chip-ActionGame")
            verify(game !== null)
            verify(game.visible)
            // Selected non-matching chip: still present — selected chips
            // lead the flow and are never filtered out.
            verify(findLive(bar, "chip-Development") !== null)
            // The Activity page's bar is a separate instance with its own
            // field: typing into the Categories page's field must not leak.
            compare(activityField.text, "")
            verify(findLive(activityBar, "chip-Audio") !== null)
            // Model level, same invariants as tst_chipbar:
            const model = bar.chipModel("game")
            verify(model.indexOf("Audio") < 0)
            verify(model.indexOf("ActionGame") >= 0)
            verify(model.indexOf("Development") >= 0)
            verify(model.indexOf("Development") < model.indexOf("ActionGame"))
        }

        // The "chipFilter" field of one category-filter page, identified by
        // the page's scroll view (page-unique objectName) — robust against
        // findChild traversal order and the duplicated objectName.
        function filterFieldOf(scrollName) {
            const scroll = findChild(nestedEditor, scrollName)
            verify(scroll !== null)
            const fields = []
            collectNamed(nestedEditor, "chipFilter", fields)
            compare(fields.length, 2)   // exactly the two pages' bars
            const own = fields.filter(field => isDescendantOf(field, scroll))
            compare(own.length, 1)
            return own[0]
        }
        // The CategoryChipBar containing a given field: the first ancestor
        // exposing chipModel (the bar's assertable model builder).
        function chipBarOf(field) {
            let item = field.parent
            while (item !== null && typeof item.chipModel !== "function") item = item.parent
            verify(item !== null)
            return item
        }
        // Live visual children only: Repeater model resets can leave removed
        // delegates unparented-but-findable, so presence and absence must be
        // checked through a fresh traversal (same helper as tst_chipbar.qml).
        function findLive(item, name) {
            if (item.objectName === name) return item
            const kids = item.children
            for (let i = 0; i < kids.length; i++) {
                const found = findLive(kids[i], name)
                if (found) return found
            }
            return null
        }
        function collectNamed(item, name, acc) {
            if (item.objectName === name) acc.push(item)
            const kids = item.children
            for (let i = 0; i < kids.length; i++) collectNamed(kids[i], name, acc)
        }
        function isDescendantOf(item, ancestor) {
            let current = item
            while (current !== null) {
                if (current === ancestor) return true
                current = current.parent
            }
            return false
        }
    }
}
