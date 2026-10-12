import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs as Dialogs
import "StackMembers.js" as StackMembers

QQC2.Dialog {
        id: customDialog
        objectName: "customLauncherDialog"
        signal saved(string entryId, string name, string executable, string argumentsText)
        function edit(id, entry) {
            entryId = id || ""
            customName.text = entry.name || ""
            customExecutable.text = entry.executable || ""
            customArguments.text = StackMembers.formatArguments(entry.arguments || [])
            open()
        }
        property string entryId: ""
        title: entryId ? i18n("Edit custom launcher") : i18n("Add custom launcher")
        parent: QQC2.Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(560, parent ? parent.width - 24 : 560)
        modal: true
        standardButtons: QQC2.Dialog.Ok | QQC2.Dialog.Cancel
        onOpened: customName.forceActiveFocus()
        onAccepted: saved(entryId, customName.text, customExecutable.text, customArguments.text)
        ColumnLayout {
            anchors.fill: parent
            QQC2.Label { text: i18n("Name:") }
            QQC2.TextField { id: customName; Layout.fillWidth: true; maximumLength: 256 }
            QQC2.Label { text: i18n("Executable path:") }
            RowLayout {
                Layout.fillWidth: true
                QQC2.TextField { id: customExecutable; Layout.fillWidth: true; maximumLength: 4096; placeholderText: "/path/to/program" }
                QQC2.Button { text: i18n("Browse…"); onClicked: executablePicker.open() }
            }
            QQC2.Label { text: i18n("Arguments (optional):") }
            QQC2.TextField { id: customArguments; Layout.fillWidth: true; maximumLength: 4096; placeholderText: '--example "value with spaces"' }
            QQC2.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: i18n("Use quotes around arguments containing spaces. Runs directly; shell variables, pipes and redirects are not expanded. Choose its icon from the list after adding.")
            }
            QQC2.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                visible: !customExecutable.text.startsWith("/") || !!StackMembers.parseArguments(customArguments.text).error
                text: i18n("Enter an absolute executable path and complete any quoted arguments.")
            }
        }
        Binding {
            target: customDialog.standardButton(QQC2.Dialog.Ok)
            property: "enabled"
            value: !!customName.text.trim() && customExecutable.text.startsWith("/")
                && !StackMembers.parseArguments(customArguments.text).error
                && StackMembers.parseArguments(customArguments.text).arguments.length <= 256
        }
        Dialogs.FileDialog {
        id: executablePicker
        title: i18n("Choose an executable")
        fileMode: Dialogs.FileDialog.OpenFile
        onAccepted: customExecutable.text = decodeURIComponent(selectedFile.toString().replace(/^file:\/\//, ""))
    }
}
