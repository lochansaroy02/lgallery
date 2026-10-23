import QtQuick
import ".."

// Round face with the person's name (or "Add a name") and picture count.
Item {
    id: avatar
    property var person: ({})
    property real size: 96
    property color maskColor: Theme.bg
    signal clicked()

    width: size + 16
    height: size + 52
    opacity: person.hidden ? 0.5 : 1

    RoundedImage {
        id: face
        anchors.horizontalCenter: parent.horizontalCenter
        width: avatar.size
        height: avatar.size
        radius: avatar.size / 2
        maskColor: avatar.maskColor
        source: avatar.person.face || ""
        scale: mouse.pressed ? 0.95 : 1
        Behavior on scale { NumberAnimation { duration: Theme.durFast } }
    }
    Rectangle {
        anchors.fill: face
        radius: width / 2
        color: "transparent"
        border.width: mouse.containsMouse ? 3 : 0
        border.color: Theme.accentSoft
    }
    Column {
        anchors.top: face.bottom
        anchors.topMargin: Theme.s2
        width: parent.width
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: avatar.person.name ? avatar.person.name : qsTr("Add a name")
            elide: Text.ElideRight
            color: avatar.person.name ? Theme.text : Theme.accent
            font.pixelSize: Theme.fontSmall + 1
            font.weight: Font.DemiBold
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: avatar.person.hidden ? qsTr("Hidden") : (avatar.person.count || 0).toLocaleString(Qt.locale(), "f", 0)
            color: Theme.textSecondary
            font.pixelSize: Theme.fontTiny + 1
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: avatar.clicked()
    }
}
