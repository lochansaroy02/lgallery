import QtQuick
import QtQuick.Controls
import "."
import "components"

// All places, grouped by country (Collections > Places > See all).
Item {
    id: page
    signal backRequested()
    signal openPlace(string key, string name)
    readonly property real collapse: Math.max(0, Math.min(1, (list.contentY - list.originY) / 140))
    readonly property var places: collections.places.slice().sort(function(a, b) {
        if (a.country !== b.country) return a.country.localeCompare(b.country)
        return b.count - a.count
    })

    CollapsingHeader {
        id: bar
        z: 2
        width: parent.width
        title: qsTr("Places")
        progress: page.collapse
        showBack: true
        onBackClicked: page.backRequested()
    }
    ListView {
        id: list
        anchors.top: bar.bottom
        anchors.bottom: parent.bottom
        width: parent.width
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: page.places
        header: BigTitle {
            width: list.width
            height: 180
            title: qsTr("Places")
            subtitle: collections.places.length === 1 ? qsTr("1 place") : qsTr("%1 places").arg(collections.places.length)
            progress: page.collapse
        }
        footer: Item { width: 1; height: Theme.s6 }
        delegate: Column {
            required property var modelData
            required property int index
            readonly property bool firstOfCountry: index === 0 || page.places[index - 1].country !== modelData.country
            width: list.width
            Text {
                visible: parent.firstOfCountry
                x: Theme.pageMargin + 4
                topPadding: index === 0 ? 0 : Theme.s4
                bottomPadding: Theme.s2
                text: modelData.country || qsTr("Unknown")
                color: Theme.accent
                font.pixelSize: Theme.fontSmall + 1
                font.weight: Font.DemiBold
            }
            Rectangle {
                x: Theme.pageMargin
                width: list.width - 2 * Theme.pageMargin
                height: 76
                radius: Theme.radiusM
                color: rowMouse.containsMouse ? Theme.surfaceHigh : Theme.surface
                RoundedImage {
                    id: cover
                    x: Theme.s2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 60
                    height: 60
                    radius: Theme.radiusS
                    maskColor: parent.color
                    source: modelData.cover
                }
                Column {
                    anchors.left: cover.right
                    anchors.leftMargin: Theme.s3
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        width: parent.width
                        text: modelData.place
                        elide: Text.ElideRight
                        color: Theme.text
                        font.pixelSize: Theme.fontBody + 1
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: modelData.count === 1 ? qsTr("1 picture") : qsTr("%1 pictures").arg(modelData.count.toLocaleString(Qt.locale(), "f", 0))
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSmall
                    }
                }
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.openPlace(modelData.key, modelData.place)
                }
            }
            Item { width: 1; height: Theme.s2 }
        }
    }
}
