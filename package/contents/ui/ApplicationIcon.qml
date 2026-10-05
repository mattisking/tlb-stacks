import QtQuick
import org.kde.kirigami as Kirigami
import "IconOverrides.js" as IconOverrides

Item {
    id: root
    property string source: ""
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
        anchors.fill: parent
        visible: !root.fromFile || image.status === Image.Error
        source: root.fromFile ? "application-x-executable" : root.source
        isMask: false
    }
}
