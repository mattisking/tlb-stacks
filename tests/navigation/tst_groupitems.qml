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
    function test_future_and_malformed_settings_preserved_as_error() {
        for (const raw of ["bad", '{"version":2,"items":[]}',
                           '{"version":1,"items":[{"id":"a","type":"stack"}]}',
                           '{"version":1,"items":[{"id":"a","type":"application","desktopId":"x"},{"id":"a","type":"application","desktopId":"y"}]}']) {
            verify(GroupItems.decode(raw).error)
        }
    }
}
