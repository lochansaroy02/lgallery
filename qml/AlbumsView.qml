import QtQuick
import QtQuick.Controls
import "."
import "components"

// Albums tab: Favorites plus one album per watched folder (or per sub-folder).
Item {
    id: view
    property real bottomInset: 0
    signal openAlbum(string kind, string key, string title)
    signal searchRequested()
    signal settingsRequested()

    readonly property int cols: Math.max(2, Math.floor((width - 2 * Theme.pageMargin) / 220))
    readonly property real headerHeight: Math.max(150, Math.min(250, height * 0.3))
    readonly property real collapse: Math.max(0, Math.min(1, (grid.contentY - grid.originY) / (headerHeight * 0.7)))

    CollapsingHeader {
        id: bar
        z: 2
        width: parent.width
        title: qsTr("Albums")
        progress: view.collapse
        IconButton { icon: "search"; tip: qsTr("Search (Ctrl+F)"); onClicked: view.searchRequested() }
        IconButton { icon: "settings"; tip: qsTr("Settings"); onClicked: view.settingsRequested() }
    }

    GridView {
        id: grid
        anchors.top: bar.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.pageMargin - Theme.s2
        anchors.rightMargin: Theme.pageMargin - Theme.s2
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: albums
        cellWidth: width / view.cols
        cellHeight: cellWidth - Theme.s4 + 64
        header: BigTitle {
            width: grid.width
            height: view.headerHeight
            title: qsTr("Albums")
            subtitle: albums.count === 1 ? qsTr("1 album") : qsTr("%1 albums").arg(albums.count)
            progress: view.collapse
        }
        footer: Item { width: 1; height: view.bottomInset + Theme.s4 }
        delegate: Item {
            required property string key
            required property string title
            required property string kind
            required property int count
            required property string cover
            required property bool available
            width: grid.cellWidth
            height: grid.cellHeight
            AlbumCard {
                anchors.fill: parent
                anchors.margins: Theme.s2
                title: parent.title
                count: parent.count
                cover: parent.cover
                available: parent.available
                favorites: parent.kind === "favorites"
                onClicked: view.openAlbum(parent.kind, parent.key, parent.title)
            }
        }
    }

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 420)
        spacing: Theme.s3
        visible: albums.count === 0
        Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "albums"; color: Theme.textSecondary; size: 44 }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: qsTr("Albums appear here once your folders have been scanned.")
            color: Theme.textSecondary
            font.pixelSize: Theme.fontBody
        }
    }
}
