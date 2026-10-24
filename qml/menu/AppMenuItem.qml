import QtQuick
import QtQuick.Controls
import ".."
import "../components"

// Menu row for the in-app menus: optional icon, label, shortcut on the right, check mark,
// submenu arrow. A submenu row takes its icon from the submenu's `iconName`.
MenuItem {
    id: item
    property string shortcutText: ""
    property string iconName: subMenu && subMenu.iconName !== undefined ? subMenu.iconName : ""
    property bool danger: false
    implicitWidth: 280
    implicitHeight: visible ? 40 : 0
    height: visible ? implicitHeight : 0
    leftPadding: iconName !== "" ? 44 : 34
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
            color: !item.enabled ? Theme.textSecondary : item.danger ? Theme.danger : Theme.text
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
        x: item.iconName !== "" ? 14 : 10
        anchors.verticalCenter: parent.verticalCenter
        visible: (item.checkable && item.checked) || item.iconName !== ""
        name: item.checkable && item.checked ? "check" : item.iconName
        size: item.iconName !== "" ? 18 : 16
        strokeWidth: item.checkable && item.checked ? 2.5 : 1.8
        color: item.checkable && item.checked ? Theme.accent
             : !item.enabled ? Theme.textSecondary : item.danger ? Theme.danger : Theme.textSecondary
        opacity: item.enabled ? 1 : 0.55
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
