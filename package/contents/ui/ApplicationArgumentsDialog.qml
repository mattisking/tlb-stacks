import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import "StackMembers.js" as StackMembers

QQC2.Dialog {
    id: root
    objectName: "applicationArgumentsDialog"
    property string entryId: ""
    signal saved(string entryId, string name, var arguments)
    function edit(id, name, args) {
        entryId = id
        labelField.text = name
        argumentsField.text = StackMembers.formatArguments(args || [])
        open()
    }
    title: i18n("Application launch options")
    parent: QQC2.Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(560, parent ? parent.width - 24 : 560)
    modal: true
    standardButtons: QQC2.Dialog.Ok | QQC2.Dialog.Cancel
    onAccepted: saved(entryId, labelField.text.trim(), StackMembers.parseArguments(argumentsField.text).arguments)
    ColumnLayout {
        anchors.fill: parent
        PlasmaComponents.Label { text: i18n("Name:") }
        PlasmaComponents.TextField { id: labelField; Layout.fillWidth: true; maximumLength: 256 }
        PlasmaComponents.Label { text: i18n("Additional arguments (optional):") }
        PlasmaComponents.TextField {
            id: argumentsField
            objectName: "applicationArgumentsField"
            Layout.fillWidth: true
            maximumLength: 4096
            placeholderText: '--example "value with spaces"'
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: i18n("Added to the application's normal launch command. Quote values containing spaces. Shell variables and commands are not expanded. Clear the arguments to use the normal launch behavior.")
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            visible: !!StackMembers.parseArguments(argumentsField.text).error
            text: i18n("Complete any quoted arguments before saving.")
        }
    }
    Binding {
        target: root.standardButton(QQC2.Dialog.Ok)
        property: "enabled"
        value: !!labelField.text.trim() && !labelField.text.includes("\0")
            && !StackMembers.parseArguments(argumentsField.text).error
            && StackMembers.validArguments(StackMembers.parseArguments(argumentsField.text).arguments)
    }
}
