import QtQuick
import QtQuick.Controls
import ".."

// Round, borderless icon button with hover/press feedback and optional tooltip.
Item {
    id: btn
    property string icon: "image"
    property color color: Theme.text
    property bool filled: false
    property string tip: ""
    property real iconSize: 22
    property bool onDark: false
    signal clicked()

    implicitWidth: 44
    implicitHeight: 44
    opacity: enabled ? 1 : 0.35

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: mouse.pressed ? (btn.onDark ? Qt.rgba(1, 1, 1, 0.2) : Theme.pressed)
             : mouse.containsMouse ? (btn.onDark ? Qt.rgba(1, 1, 1, 0.12) : Theme.hover)
             : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }
    Icon {
        anchors.centerIn: parent
        name: btn.icon
        color: btn.color
        filled: btn.filled
        size: btn.iconSize
        scale: mouse.pressed ? 0.9 : 1
        Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing } }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
    ToolTip.visible: tip !== "" && mouse.containsMouse
    ToolTip.delay: 600
    ToolTip.text: tip
}
