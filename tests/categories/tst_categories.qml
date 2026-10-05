import QtQuick
import QtTest
import "../../package/contents/ui/ApplicationCategories.js" as Categories

TestCase {
    name: "ApplicationCategories"
    readonly property var apps: [
        {desktopId: "z", name: "Zulu", categories: ["Development", "IDE"]},
        {desktopId: "a", name: "Alpha", categories: ["Graphics"]},
        {desktopId: "b", name: "Beta", categories: ["Development", "Graphics"]},
        {desktopId: "z", name: "Zulu", categories: ["Development"]},
        {desktopId: "n", name: "None", categories: []}
    ]
    function test_any_deduplicated_sorted() {
        compare(Categories.matching(apps, ["Development", "Graphics"]).map(app => app.desktopId), ["a", "b", "z"])
    }
    function test_exact_category_and_empty_selection() {
        compare(Categories.matching(apps, ["development"]).length, 0)
        compare(Categories.matching(apps, []).length, 0)
        compare(Categories.matching(apps, ["IDE"]).map(app => app.desktopId), ["z"])
    }
    function test_retained_selection_and_catalog_update() {
        compare(Categories.available(apps, ["PreviouslyInstalled"]), ["Development", "Graphics", "IDE", "PreviouslyInstalled"])
        compare(Categories.matching(apps.slice(1, 3), ["IDE"]).length, 0)
    }
}
