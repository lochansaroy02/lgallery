import QtQuick
import QtQuick.Controls
import ".."

// The large left-aligned title area at the top of a scrolling page.
Item {
    id: big
    property string title: ""
    property string subtitle: ""
    property bool busy: false
    property real progress: 0

    Column {
        anchors.left: parent.left
        anchors.leftMargin: Theme.pageMargin + 4
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.s6
        spacing: Theme.s2
        opacity: 1 - Math.min(1, big.progress * 1.6)
        scale: 1 - big.progress * 0.08
        transformOrigin: Item.BottomLeft

        Text {
            width: parent.width
            text: big.title
            elide: Text.ElideRight
            color: Theme.text
            font.pixelSize: Theme.fontHuge
            font.weight: Font.Bold
        }
        Row {
            spacing: Theme.s2
            BusyIndicator {
                visible: big.busy
                running: big.busy
                width: 18
                height: 18
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: big.subtitle
                color: Theme.textSecondary
                font.pixelSize: Theme.fontBody
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
