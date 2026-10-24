import QtQuick
import ".."

// One UI style toggle switch.
Item {
    id: sw
    property bool checked: false
    signal toggled(bool checked)
    implicitWidth: 50
    implicitHeight: 28
    opacity: enabled ? 1 : 0.4

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: sw.checked ? Theme.accent : Theme.switchOff
        Behavior on color { ColorAnimation { duration: Theme.durNormal } }
        Rectangle {
            width: 22
            height: 22
            radius: 11
            y: 3
            x: sw.checked ? parent.width - width - 3 : 3
            color: "white"
            Behavior on x { NumberAnimation { duration: Theme.durNormal; easing.type: Theme.easing } }
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: { sw.checked = !sw.checked; sw.toggled(sw.checked) }
    }
}
