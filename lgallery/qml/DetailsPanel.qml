import QtQuick
import "."
import "components"

// Bottom sheet with file details for the picture shown in the viewer.
Rectangle {
    id: panel
    property var info: ({})
    signal closeRequested()

    height: col.implicitHeight + Theme.s5 * 2
    radius: Theme.radiusXL
    color: Theme.surface

    // square off the bottom corners
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: parent.radius
        color: parent.color
    }

    function megapixels() {
        if (!(info.width > 0)) return ""
        return " · " + (info.width * info.height / 1e6).toFixed(1) + " MP"
    }

    Column {
        id: col
        x: Theme.s5
        y: Theme.s5
        width: parent.width - 2 * Theme.s5
        spacing: Theme.s4

        Item {
            width: parent.width
            height: 36
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: -Theme.s3
                width: 36
                height: 4
                radius: 2
                color: Theme.divider
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Details")
                color: Theme.text
                font.pixelSize: Theme.fontTitle
                font.weight: Font.Bold
            }
            IconButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                icon: "close"
                onClicked: panel.closeRequested()
            }
        }

        component Field: Row {
            property string icon
            property string label
            property string value
            property bool selectable: false
            spacing: Theme.s4
            width: parent.width
            Rectangle {
                width: 40
                height: 40
                radius: 20
                color: Theme.surfaceHigh
                Icon { anchors.centerIn: parent; name: parent.parent.icon; size: 19; color: Theme.textSecondary }
            }
            Column {
                width: parent.width - 56
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    text: label
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSmall
                }
                TextEdit {
                    width: parent.width
                    text: value
                    readOnly: true
                    selectByMouse: true
                    wrapMode: Text.WrapAnywhere
                    color: Theme.text
                    selectionColor: Theme.accent
                    font.pixelSize: Theme.fontBody
                }
            }
        }

        Field { icon: "pictures"; label: qsTr("Date taken"); value: panel.info.date || "" }
        Field { icon: "image"; label: qsTr("File name"); value: panel.info.name || "" }
        Field {
            icon: "zoomIn"
            label: qsTr("Resolution")
            value: panel.info.width > 0 ? panel.info.width + " × " + panel.info.height + panel.megapixels() : qsTr("Unknown")
        }
        Field { icon: "drive"; label: qsTr("Size"); value: panel.info.size || "" }
        Field {
            icon: "folder"
            label: panel.info.available === false ? qsTr("Path (drive not available)") : qsTr("Path")
            value: panel.info.path || ""
        }

        Row {
            spacing: Theme.s2
            PillButton {
                compact: true
                kind: "tonal"
                icon: "showFolder"
                text: qsTr("Show in folder")
                onClicked: gallery.showInFolder(panel.info.path)
            }
            PillButton {
                compact: true
                kind: "tonal"
                icon: "copy"
                text: qsTr("Copy path")
                onClicked: gallery.copyPaths([panel.info.path])
            }
        }
    }
}
