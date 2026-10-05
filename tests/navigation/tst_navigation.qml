import QtQuick
import QtTest
import "../../package/contents/ui/MenuNavigation.js" as Navigation
TestCase {
    name: "SharedRootNavigation"
    function test_firstAndLast() {
        compare(Navigation.nextIndex(4, -1, -1, false, 1), 0)
        compare(Navigation.nextIndex(4, -1, -1, false, -1), 3)
    }
    function test_wrap() {
        compare(Navigation.nextIndex(4, 3, -1, true, 1), 0)
        compare(Navigation.nextIndex(4, 0, -1, true, -1), 3)
    }
    function test_hoverHandoff() {
        compare(Navigation.nextIndex(4, 0, 2, false, 1), 3)
        compare(Navigation.nextIndex(4, 0, 2, false, -1), 1)
        compare(Navigation.nextIndex(4, 1, 2, true, 1), 2)
    }
    function test_emptyAndStaleSelection() {
        compare(Navigation.nextIndex(0, 2, 2, true, 1), -1)
        compare(Navigation.nextIndex(2, 7, -1, true, -1), 1)
    }
}
