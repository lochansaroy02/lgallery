import QtQuick
import ".."

// Top bar of the One UI collapsing header. The big title lives in the list's
// header (BigTitle); as it scrolls away this bar fades in a small title.
Rectangle {
    id: bar
    property string title: ""
    property real progress: 0         // 0 = expanded, 1 = collapsed
    property bool showBack: false
    property string backIcon: "back"
    property Component middle: null   // optional replacement for the small title
    default property alias actions: actionRow.data
    signal backClicked()

    height: Theme.barHeight
    color: Theme.bg

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Theme.divider
        opacity: bar.progress
    }

    IconButton {
        id: back
        visible: bar.showBack
        anchors.left: parent.left
        anchors.leftMargin: Theme.s2
        anchors.verticalCenter: parent.verticalCenter
        icon: bar.backIcon
        onClicked: bar.backClicked()
    }
    Item {
        anchors.left: back.visible ? back.right : parent.left
        anchors.leftMargin: back.visible ? Theme.s1 : Theme.pageMargin
        anchors.right: actionRow.left
        anchors.rightMargin: Theme.s2
        height: parent.height

        Text {
            visible: bar.middle === null
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            text: bar.title
            elide: Text.ElideRight
            color: Theme.text
            font.pixelSize: Theme.fontTitle
            font.weight: Font.Bold
            opacity: Math.max(0, (bar.progress - 0.55) / 0.45)
            transform: Translate { y: (1 - Math.min(1, bar.progress * 1.2)) * 10 }
        }
        Loader {
            width: parent.width
            anchors.verticalCenter: parent.verticalCenter
            sourceComponent: bar.middle
        }
    }
    Row {
        id: actionRow
        anchors.right: parent.right
        anchors.rightMargin: Theme.s2
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
    }
}
