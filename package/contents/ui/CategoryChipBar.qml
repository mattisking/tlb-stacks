import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// Filterable cloud of category chips (mockup frames 07-08): pills in a
// wrapping flow, accent fill + check glyph + bold label = selected.
// Selection is data-driven via categoryToggled(name, on); the host owns the
// `selected` array. Selected chips lead the flow and are NEVER removed by
// the filter — filtering only narrows the unselected choices, so what is
// selected stays visible at all times (the user's core complaint).
ColumnLayout {
    id: root

    property var categories: []
    property var selected: []
    property string caption: ""
    signal categoryToggled(string name, bool on)

    // Ordered chip model: every selected category first (in `categories`
    // order), then the unselected ones matching the filter text. Exposed as
    // a function so the never-hides-selected invariant stays assertable
    // headlessly (tst_chipbar.qml test_filter_never_hides_selected_chips).
    function chipModel(filterText) {
        const query = (filterText || "").toLowerCase()
        const chosen = root.categories.filter(name => root.selected.includes(name))
        const choices = root.categories.filter(name =>
            !root.selected.includes(name) && name.toLowerCase().includes(query))
        return chosen.concat(choices)
    }

    spacing: Kirigami.Units.smallSpacing

    PlasmaComponents.TextField {
        id: filter
        objectName: "chipFilter"
        Layout.fillWidth: true
        placeholderText: i18n("Filter categories…")
        clearButtonShown: true
        Accessible.name: i18n("Filter categories")
        Keys.onReturnPressed: event => { event.accepted = true }
        Keys.onEnterPressed: event => { event.accepted = true }
    }

    PlasmaComponents.Label {
        // Old-design count line: the selection is stated in words, not just
        // implied by chip styling.
        Layout.fillWidth: true
        text: i18n("Categories (%1 selected)", root.selected.length)
        textFormat: Text.PlainText
        font: Kirigami.Theme.smallFont
        opacity: 0.7
        elide: Text.ElideRight
    }

    Flow {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Kirigami.Units.smallSpacing

        Repeater {
            model: root.chipModel(filter.text)
            delegate: PlasmaComponents.ToolButton {
                id: chip
                required property string modelData
                readonly property bool isSelected: root.selected.includes(modelData)
                objectName: "chip-" + modelData
                text: modelData
                // No Qt-managed toggle state (`checkable`/`checked`): real
                // pointer clicks imperatively flip `checked` and break its
                // binding. The selected look is derived from the host-owned
                // array instead, so visual state can never desync from it.
                highlighted: isSelected
                icon.name: isSelected ? "checkmark" : ""
                font.weight: isSelected ? Font.Bold : Font.Normal
                // Unselected chips sit back (flat, muted) so the selected
                // ones read as a leading group at a glance.
                opacity: isSelected ? 1.0 : 0.7
                Accessible.role: Accessible.Button
                Accessible.name: isSelected
                    ? i18n("Category %1, selected", modelData)
                    : i18n("Category %1", modelData)
                // Emit intent from the host-owned `selected`, not `checked`:
                // Qt flips `checked` before emitting `clicked` on real pointer
                // input (but not on direct signal calls), so `!checked` would
                // report the inverse of the user's action in production.
                onClicked: root.categoryToggled(modelData, !isSelected)
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
