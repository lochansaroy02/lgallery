import QtQuick
import ".."

// The round selection check used on thumbnails and day headers.
Rectangle {
    id: c
    property bool checked: false
    property bool onImage: true
    property real size: 22
    width: size
    height: size
    radius: size / 2
    color: checked ? Theme.accent : (onImage ? Qt.rgba(0, 0, 0, 0.25) : "transparent")
    border.width: checked ? 0 : 2
    border.color: onImage ? "white" : Theme.textSecondary
    Behavior on color { ColorAnimation { duration: Theme.durFast } }
    Icon {
        anchors.centerIn: parent
        name: "check"
        color: Theme.tinted ? Theme.accentText : "white"
        size: c.size * 0.62
        strokeWidth: 3
        visible: c.checked
        scale: c.checked ? 1 : 0.4
        Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutBack } }
    }
}
