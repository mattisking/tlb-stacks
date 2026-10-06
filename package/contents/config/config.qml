import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: "General"
        icon: Qt.resolvedUrl("../images/tlbstacks.svg")
        source: "ConfigGeneral.qml"
    }
}