import QtQuick
import QtQuick.Controls
import ".."

// The large title area at the top of a scrolling page (it starts under the top bar). Like
// One UI, the title sits centred in it, in a large display size, with the count underneath; it
// shrinks and fades as the page scrolls and the small title in the top bar takes over.
Item {
    id: big
    property string title: ""
    property string subtitle: ""
    property bool busy: false
    property real progress: 0
    property bool centered: true

    Column {
        id: block
        x: big.centered ? (big.width - width) / 2 : Theme.pageMargin + 4
        width: big.width - 2 * (Theme.pageMargin + 4)
        y: big.centered ? (big.height - height) / 2 : big.height - height - Theme.s6
        spacing: Theme.s2
        opacity: 1 - Math.min(1, big.progress * 1.6)
        scale: 1 - big.progress * 0.1
        transformOrigin: big.centered ? Item.Center : Item.BottomLeft

        Text {
            width: parent.width
            text: big.title
            elide: Text.ElideRight
            horizontalAlignment: big.centered ? Text.AlignHCenter : Text.AlignLeft
            color: Theme.text
            font.pixelSize: big.centered ? Theme.fontDisplay : Theme.fontHuge
            font.weight: Font.Bold
            font.letterSpacing: big.centered ? -0.5 : 0
        }
        Row {
            anchors.horizontalCenter: big.centered ? parent.horizontalCenter : undefined
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
