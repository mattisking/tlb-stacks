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
        const invalid = GroupItems.updateStack(changed, changed[1].id, {menuSource: "folder"})
        verify(GroupItems.decode(GroupItems.encode(invalid)).error)
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
    function test_future_and_malformed_settings_preserved_as_error() {
        for (const raw of ["bad", '{"version":3,"items":[]}',
                           '{"version":1,"items":[{"id":"a","type":"stack"}]}',
                           '{"version":1,"items":[{"id":"a","type":"application","desktopId":"x"},{"id":"a","type":"application","desktopId":"y"}]}']) {
            verify(GroupItems.decode(raw).error)
        }
    }
}
