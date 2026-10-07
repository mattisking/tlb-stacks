import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// Filterable cloud of category chips (mockup frames 07-08): pills in a
// wrapping flow, filled = selected. Selection is data-driven via
// categoryToggled(name, on); the host owns the `selected` array.
ColumnLayout {
    id: root

    property var categories: []
    property var selected: []
    property string caption: ""
    signal categoryToggled(string name, bool on)

    spacing: Kirigami.Units.smallSpacing

    PlasmaComponents.TextField {
        id: filter
        objectName: "chipFilter"
        Layout.fillWidth: true
        placeholderText: i18n("Filter categories…")
        clearButtonShown: true
        Keys.onReturnPressed: event => { event.accepted = true }
        Keys.onEnterPressed: event => { event.accepted = true }
    }

    Flow {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Kirigami.Units.smallSpacing

        Repeater {
            model: {
                const query = filter.text.toLowerCase()
                return root.categories.filter(name => name.toLowerCase().includes(query))
            }
            delegate: PlasmaComponents.ToolButton {
                id: chip
                required property string modelData
                objectName: "chip-" + modelData
                text: modelData
                checkable: true
                checked: root.selected.includes(modelData)
                Accessible.name: i18n("Category %1", modelData)
                // Emit intent from the host-owned `selected`, not `checked`:
                // Qt flips `checked` before emitting `clicked` on real pointer
                // input (but not on direct signal calls), so `!checked` would
                // report the inverse of the user's action in production.
                onClicked: root.categoryToggled(modelData, !root.selected.includes(modelData))
                // `checked` follows the host's `selected` array; flip visually on click.
                Connections {
                    target: root
                    function onSelectedChanged() { chip.checked = root.selected.includes(chip.modelData) }
                }
            }
        }
    }

    PlasmaComponents.Label {
        Layout.fillWidth: true
        visible: root.caption.length > 0
        text: root.caption
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        opacity: 0.7
        font: Kirigami.Theme.smallFont
    }
}
