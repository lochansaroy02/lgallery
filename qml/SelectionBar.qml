import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "."
import "components"

// Floating action bar shown in selection mode.
Item {
    id: bar
    required property var photoModel
    signal finished()

    readonly property int count: photoModel.selectionCount
    readonly property var win: ApplicationWindow.window

    implicitWidth: row.implicitWidth + Theme.s4 * 2
    implicitHeight: 72

    MultiEffect {
        source: pill
        anchors.fill: pill
        shadowEnabled: true
        shadowColor: Theme.shadow
        shadowBlur: 1.0
        shadowVerticalOffset: 4
        autoPaddingEnabled: true
    }
    Rectangle {
        id: pill
        anchors.fill: parent
        radius: Theme.radiusXL
        color: Theme.navBg

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 2

            component Action: Item {
                id: action
                property string icon
                property string label
                property bool danger: false
                property bool filledIcon: false
                signal triggered()
                width: 76
                height: 60
                enabled: bar.count > 0
                opacity: enabled ? 1 : 0.35
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusM
                    color: m.pressed ? Theme.pressed : m.containsMouse ? Theme.hover : "transparent"
                }
                Column {
                    anchors.centerIn: parent
                    spacing: 4
                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: action.icon
                        filled: action.filledIcon
                        color: action.danger ? Theme.danger : Theme.text
                        size: 21
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: action.label
                        color: action.danger ? Theme.danger : Theme.text
                        font.pixelSize: Theme.fontTiny + 1
                    }
                }
                MouseArea {
                    id: m
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: action.triggered()
                }
            }

            Action {
                id: shareAction
                icon: "share"
                label: qsTr("Share")
                onTriggered: bar.win.share(bar.photoModel.selectedPaths(), shareAction, function() { bar.finished() })
            }
            Action {
                id: favAction
                readonly property bool allFav: bar.count > 0 && bar.photoModel.selectionAllFavorite()
                icon: "heart"
                filledIcon: allFav
                label: allFav ? qsTr("Unfavorite") : qsTr("Favorite")
                onTriggered: {
                    gallery.setFavorite(bar.photoModel.selectedIds(), !allFav)
                    bar.finished()
                }
            }
            Action {
                icon: "openWith"
                label: qsTr("Open with")
                onTriggered: bar.win.openWith(bar.photoModel.selectedPaths())
            }
            Action {
                icon: "copy"
                label: qsTr("Copy path")
                onTriggered: gallery.copyPaths(bar.photoModel.selectedPaths())
            }
            Action {
                icon: "showFolder"
                label: qsTr("Show")
                onTriggered: gallery.showInFolder(bar.photoModel.selectedPaths()[0])
            }
            Action {
                icon: "trash"
                label: qsTr("Delete")
                danger: true
                onTriggered: bar.win.confirmDelete(bar.photoModel.selectedPaths(), function() { bar.finished() })
            }
        }
    }
}
