import QtQuick
import QtQuick.Controls
import ".."
import "../components"

// Menu row for the in-app menu: label, shortcut on the right, check mark, submenu arrow.
MenuItem {
    id: item
    property string shortcutText: ""
    implicitWidth: 280
    implicitHeight: visible ? 38 : 0
    height: visible ? implicitHeight : 0
    leftPadding: 34
    rightPadding: 14

    contentItem: Item {
        implicitHeight: 38
        Text {
            anchors.left: parent.left
            anchors.right: keys.left
            anchors.rightMargin: Theme.s3
            anchors.verticalCenter: parent.verticalCenter
            text: item.text.replace("&", "")
            elide: Text.ElideRight
            color: item.enabled ? Theme.text : Theme.textSecondary
            opacity: item.enabled ? 1 : 0.55
            font.pixelSize: Theme.fontBody - 1
        }
        Text {
            id: keys
            anchors.right: parent.right
            anchors.rightMargin: item.subMenu ? 14 : 0
            anchors.verticalCenter: parent.verticalCenter
            text: item.shortcutText
            color: Theme.textSecondary
            opacity: item.enabled ? 1 : 0.55
            font.pixelSize: Theme.fontSmall
        }
    }
    indicator: Icon {
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        visible: item.checkable && item.checked
        name: "check"
        size: 16
        strokeWidth: 2.5
        color: Theme.accent
    }
    arrow: Icon {
        x: item.width - width - 8
        anchors.verticalCenter: parent.verticalCenter
        visible: item.subMenu !== null
        name: "chevronRight"
        size: 16
        color: Theme.textSecondary
    }
    background: Rectangle {
        implicitWidth: 280
        radius: Theme.radiusS - 2
        color: item.highlighted && item.enabled ? Theme.hover : "transparent"
    }
}
