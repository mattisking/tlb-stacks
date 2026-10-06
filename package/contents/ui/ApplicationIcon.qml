import QtQuick
import org.kde.kirigami as Kirigami
import "IconOverrides.js" as IconOverrides

Item {
    id: root
    property string source: ""
    property string fallbackSource: ""
    property bool sourceAvailable: true
    readonly property bool useAppFallback: fallbackSource.length > 0 && fallbackSource !== source
        && (fromFile ? image.status === Image.Error : !sourceAvailable)
    implicitWidth: 22
    implicitHeight: 22
    readonly property bool fromFile: IconOverrides.isFile(source)
    readonly property url fileUrl: source.startsWith("/")
        ? "file://" + source.split("/").map(part => encodeURIComponent(part)).join("/")
        : source

    // Custom artwork should not pass through the theme icon renderer.
    Image {
        id: image
        anchors.fill: parent
        visible: root.fromFile && status !== Image.Error
        source: root.fromFile ? root.fileUrl : ""
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
    }

    Kirigami.Icon {
        id: themeIcon
        anchors.fill: parent
        visible: !root.useAppFallback && (!root.fromFile || image.status === Image.Error)
        source: root.fromFile ? "application-x-executable" : root.source
        fallback: root.fallbackSource.length > 0 && root.fallbackSource !== root.source
            ? "" : "application-x-executable"
        isMask: false
    }
    Loader {
        anchors.fill: parent
        active: root.useAppFallback
        // Load only on failure; the child has no further app fallback.
        source: active ? Qt.resolvedUrl("ApplicationIcon.qml") : ""
        onLoaded: item.source = Qt.binding(() => root.fallbackSource)
    }
}
