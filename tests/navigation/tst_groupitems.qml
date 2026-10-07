import QtQuick
import QtTest
import "../../package-group/contents/ui/GroupItems.js" as GroupItems

TestCase {
    name: "GroupEntries"
    function test_roundtrip_and_stable_identity() {
        const first = GroupItems.add([], "editor.desktop")
        const two = GroupItems.add(first, "browser.desktop")
        const moved = GroupItems.move(two, 1, -1)
        compare(first.length, 1) // Staging edits never mutate the prior snapshot.
        compare(two[0].desktopId, "editor.desktop")
        compare(moved[0].id, two[1].id)
        compare(GroupItems.decode(GroupItems.encode(moved)).items, moved)
        const removed = GroupItems.remove(moved, 0)
        compare(removed[0].id, first[0].id)
    }
    function test_duplicates_boundaries_and_empty() {
        const one = GroupItems.add([], "editor.desktop")
        compare(GroupItems.add(one, "editor.desktop").length, 1)
        compare(GroupItems.move(one, 0, -1), one)
        compare(GroupItems.move(one, 0, 1), one)
        compare(GroupItems.decode(GroupItems.encode(GroupItems.remove(one, 0))).items.length, 0)
    }
    function test_stacks_are_isolated_and_versioned() {
        const old = GroupItems.encode(GroupItems.add([], "direct.desktop"))
        compare(JSON.parse(old).version, 1)
        const original = GroupItems.addStack(GroupItems.addStack(GroupItems.decode(old).items))
        const changed = GroupItems.updateStack(original, original[1].id,
            {groupName: "Tools", applications: ["editor.desktop"]})
        compare(original[1].settings.applications.length, 0)
        compare(changed[2].settings.applications.length, 0)
        compare(changed[0].desktopId, "direct.desktop")
        compare(JSON.parse(GroupItems.encode(changed)).version, 2)
        const restored = GroupItems.decode(GroupItems.encode(changed))
        verify(!restored.error)
        compare(restored.items[1].settings.groupName, "Tools")
        compare(restored.items[1].settings.applications[0], "editor.desktop")
        const invalid = GroupItems.updateStack(changed, changed[1].id, {menuSource: "unsupported"})
        verify(GroupItems.decode(GroupItems.encode(invalid)).error)
    }
    function test_imported_stack_gets_new_identity_and_keeps_icons() {
        const original = GroupItems.addStack([])
        const settings = Object.assign({}, original[0].settings,
            {applicationIcons: {editor: "/tmp/custom.svg"}})
        const appended = GroupItems.appendImportedStack(original, settings)
        compare(appended.length, 2)
        verify(appended[0].id !== appended[1].id)
        compare(GroupItems.decode(GroupItems.encode(appended)).items[1].settings.applicationIcons.editor, "/tmp/custom.svg")
    }
    function test_sources_roundtrip_and_old_defaults() {
        let items = GroupItems.addStack([])
        const id = items[0].id
        compare(GroupItems.decode(GroupItems.encode(items)).items[0].settings.activityLimit, 10)
        for (const source of ["categories", "activity", "folder"]) {
            items = GroupItems.updateStack(items, id, {menuSource: source,
                applicationCategories: ["Development"], activityOrder: "frequent", activityLimit: 7,
                activityCurrent: true, folderUrl: "file:///tmp/tools", folderFilters: "*.pdf;*.txt"})
            const encoded = GroupItems.encode(items)
            compare(JSON.parse(encoded).version, 3)
            const decoded = GroupItems.decode(encoded)
            verify(!decoded.error)
            compare(decoded.items[0].settings.menuSource, source)
            compare(decoded.items[0].settings.activityLimit, 7)
            compare(decoded.items[0].settings.folderFilters, "*.pdf;*.txt")
        }
        for (const change of [{activityLimit: 0}, {activityLimit: 51}, {activityCurrent: "yes"},
                              {applicationCategories: ["IDE", "IDE"]}, {folderUrl: "smb://server/share"}]) {
            verify(GroupItems.decode(GroupItems.encode(GroupItems.updateStack(items, id, change))).error)
        }
        items = GroupItems.updateStack(items, id, {menuSource: "applications"})
        compare(GroupItems.decode(GroupItems.encode(items)).items[0].settings.folderUrl, "file:///tmp/tools")
    }
    function test_separator_labels_identity_and_roundtrip() {
        let apps = GroupItems.appendSeparator(["editor.desktop"])
        const id = apps[1]
        apps = GroupItems.renameSeparator(apps, id, "Tools: Büro")
        compare(GroupItems.separatorLabel(apps[1]), "Tools: Büro")
        apps = GroupItems.appendSeparator(apps)
        verify(apps[2] !== id)
        const stack = GroupItems.addStack([])
        const updated = GroupItems.updateStack(stack, stack[0].id, {applications: apps})
        compare(GroupItems.decode(GroupItems.encode(updated)).items[0].settings.applications, apps)
        compare(GroupItems.renameSeparator(apps, apps[1], "")[1], id)
    }
    function test_launcher_overrides_preserve_identity_and_version() {
        const initial = GroupItems.add([], "app.desktop")
        const changed = GroupItems.updateLauncherAppearance(initial, initial[0].id, {label: "My app", icon: "folder"})
        compare(JSON.parse(GroupItems.encode(changed)).version, 4)
        compare(GroupItems.decode(GroupItems.encode(changed)).items, changed)
        verify(!initial[0].label)
        const replaced = GroupItems.replaceLauncher(changed, changed[0].id, "other.desktop")
        compare(replaced[0].label, "My app")
        compare(replaced[0].id, initial[0].id)
        for (const invalid of [{label: 4}, {label: "x".repeat(257)}, {icon: []}]) {
            verify(GroupItems.decode(GroupItems.encode(GroupItems.updateLauncherAppearance(initial, initial[0].id, invalid))).error)
        }
    }
    function test_future_and_malformed_settings_preserved_as_error() {
        for (const raw of ["bad", '{"version":5,"items":[]}',
                           '{"version":1,"items":[{"id":"a","type":"stack"}]}',
                           '{"version":1,"items":[{"id":"a","type":"application","desktopId":"x"},{"id":"a","type":"application","desktopId":"y"}]}']) {
            verify(GroupItems.decode(raw).error)
        }
    }
    function test_replace_launcher_keeps_id_and_position_and_blocks_duplicates() {
        let items = GroupItems.add([], "one.desktop")
        items = GroupItems.add(items, "two.desktop")
        const replaced = GroupItems.replaceLauncher(items, "item-1", "three.desktop")
        compare(replaced.length, 2)
        compare(replaced[0].id, "item-1")
        compare(replaced[0].desktopId, "three.desktop")
        // Same app stays valid and unchanged.
        compare(GroupItems.replaceLauncher(replaced, "item-1", "three.desktop"), replaced)
        // Duplicate rejection: item-2 already owns two.desktop.
        compare(GroupItems.replaceLauncher(replaced, "item-1", "two.desktop"), replaced)
        // Unknown ids pass through.
        compare(GroupItems.replaceLauncher(replaced, "missing", "x.desktop"), replaced)
        verify(!GroupItems.decode(GroupItems.encode(replaced)).error)
    }
}
