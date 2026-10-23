import QtQuick
import ".."

// Rounded square cover with the album name and item count underneath.
Item {
    id: card
    property string title
    property int count
    property string cover
    property bool available: true
    property bool favorites: false
    signal clicked()

    implicitHeight: width + 56

    Rectangle {
        id: coverBox
        width: parent.width
        height: width
        radius: Theme.radiusL
        color: Theme.placeholder
        scale: mouse.pressed ? 0.97 : 1
        Behavior on scale { NumberAnimation { duration: Theme.durFast } }

        RoundedImage {
            anchors.fill: parent
            source: card.cover
            radius: Theme.radiusL
            opacity: card.available ? 1 : 0.5
        }
        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusL
            color: "transparent"
            border.width: mouse.containsMouse ? 3 : 0
            border.color: Theme.accentSoft
        }
        Rectangle {
            visible: card.favorites || !card.available
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 10
            width: 30
            height: 30
            radius: 15
            color: Qt.rgba(0, 0, 0, 0.35)
            Icon {
                anchors.centerIn: parent
                name: card.favorites ? "heart" : "unavailable"
                filled: card.favorites
                color: "white"
                size: 16
            }
        }
    }
    Column {
        anchors.top: coverBox.bottom
        anchors.topMargin: Theme.s2
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.right: parent.right
        spacing: 1
        Text {
            width: parent.width
            text: card.title
            elide: Text.ElideRight
            color: Theme.text
            font.pixelSize: Theme.fontBody
            font.weight: Font.DemiBold
        }
        Text {
            text: card.available ? card.count.toLocaleString(Qt.locale(), "f", 0)
                                 : card.count.toLocaleString(Qt.locale(), "f", 0) + " · " + qsTr("unavailable")
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSmall
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.clicked()
    }
}
