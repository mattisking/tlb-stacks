import QtQuick
import QtTest
import com.mattphilmon.tlbstacks

Rectangle {
    width: 500; height: 400
    AppPickerDialog {
        id: picker
        anchors.centerIn: parent
        applications: [
            {desktopId: "org.kde.dolphin", name: "Dolphin", icon: "system-file-manager"},
            {desktopId: "firefox", name: "Firefox", icon: "firefox"},
            {desktopId: "code", name: "Visual Studio Code", icon: "code"}
        ]
        exclude: ["firefox"]
    }
    SignalSpy { id: spy; target: picker; signalName: "picked" }
    TestCase {
        name: "AppPickerDialog"
        when: windowShown
        // QQC2.Dialog is not an Item, so TestCase.findChild's visual search
        // cannot start from it, and ListView delegates are not linked to the
        // dialog through QObject parents either (verified offscreen: the C++
        // QObject fallback finds neither, while an Item anchor works). Row
        // and field lookups therefore anchor at the dialog's contentItem.
        function test_excluded_apps_are_hidden_and_pick_emits() {
            picker.openPicker()
            verify(picker.opened)
            verify(!findChild(picker.contentItem, "pick-firefox"))
            const row = findChild(picker.contentItem, "pick-org.kde.dolphin")
            verify(row)
            row.clicked()
            compare(spy.count, 1)
            compare(spy.signalArguments[0][0], "org.kde.dolphin")
            verify(!picker.opened)
        }
        function test_search_narrows_the_list() {
            picker.openPicker()
            const search = findChild(picker.contentItem, "pickerSearch")
            search.text = "code"
            // The filter model removes non-matching delegates from the tree
            // (same as the chip bar), so they are gone, not hidden.
            verify(!findChild(picker.contentItem, "pick-org.kde.dolphin"))
            verify(findChild(picker.contentItem, "pick-code").visible)
            picker.close()
        }
    }
}
