import QtQuick
import QtQuick.Controls
import ".."

// Lists the desktop applications that can open the given file(s).
Popup {
    id: pop
    property var paths: []
    property var apps: []

    function show(filePaths) {
        paths = filePaths
        apps = filePaths.length ? gallery.appsFor(filePaths[0]) : []
        open()
    }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(380, parent ? parent.width - 48 : 380)
    height: Math.min(520, list.contentHeight + 96)
    modal: true
    focus: true
    padding: Theme.s4
    Overlay.modal: Rectangle { color: Theme.scrim }
    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durNormal }
        NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: Theme.durNormal; easing.type: Theme.easing }
    }
    background: Rectangle { radius: Theme.radiusL; color: Theme.surface }

    contentItem: Column {
        spacing: Theme.s2
        Text {
            text: qsTr("Open with")
            color: Theme.text
            font.pixelSize: Theme.fontLarge + 1
            font.weight: Font.Bold
            leftPadding: Theme.s2
            bottomPadding: Theme.s2
        }
        ListView {
            id: list
            width: parent.width
            height: pop.height - 96
            clip: true
            model: [{ name: qsTr("Default application"), icon: "", file: "" }].concat(pop.apps)
            delegate: Rectangle {
                required property var modelData
                width: list.width
                height: 52
                radius: Theme.radiusS
                color: rowMouse.containsMouse ? Theme.hover : "transparent"
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Theme.s3
                    spacing: Theme.s3
                    Item {
                        width: 32
                        height: 32
                        anchors.verticalCenter: parent.verticalCenter
                        Image {
                            id: appIcon
                            anchors.fill: parent
                            source: modelData.icon ? "image://icon/" + modelData.icon : ""
                            sourceSize: Qt.size(64, 64)
                            visible: status === Image.Ready && implicitWidth > 1
                        }
                        Icon {
                            anchors.centerIn: parent
                            visible: !appIcon.visible
                            name: "openWith"
                            color: Theme.accent
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.name
                        color: Theme.text
                        font.pixelSize: Theme.fontBody
                    }
                }
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (modelData.file === "")
                            pop.paths.forEach(p => gallery.openExternally(p))
                        else
                            gallery.openWith(modelData.file, pop.paths)
                        pop.close()
                    }
                }
            }
        }
    }
}
