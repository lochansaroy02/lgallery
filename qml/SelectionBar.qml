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
    readonly property bool privateMode: photoModel === privatePhotos   // inside the private album
    // shrink the buttons on narrow windows so the bar always fits
    readonly property real actionWidth: Math.max(56, Math.min(76,
        ((parent ? parent.width : 800) - 2 * Theme.s4 - 24) / (privateMode ? 2 : 7)))
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
                width: bar.actionWidth
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

            // ---- inside the private album ----
            Action {
                visible: bar.privateMode
                icon: "unlock"
                label: qsTr("Move out")
                onTriggered: bar.win.moveOutOfPrivate(bar.photoModel.selectedIds(), function() { bar.finished() })
            }
            Action {
                visible: bar.privateMode
                icon: "trash"
                label: qsTr("Delete")
                danger: true
                onTriggered: bar.win.deletePrivate(bar.photoModel.selectedIds(), function() { bar.finished() })
            }

            // ---- everywhere else ----
            Action {
                id: shareAction
                visible: !bar.privateMode
                icon: "share"
                label: qsTr("Share")
                onTriggered: bar.win.share(bar.photoModel.selectedPaths(), shareAction, function() { bar.finished() })
            }
            Action {
                id: favAction
                visible: !bar.privateMode
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
                visible: !bar.privateMode
                icon: "lock"
                label: qsTr("Private")
                onTriggered: bar.win.moveToPrivate(bar.photoModel.selectedPaths(), function() { bar.finished() })
            }
            Action {
                visible: !bar.privateMode
                icon: "openWith"
                label: qsTr("Open with")
                onTriggered: bar.win.openWith(bar.photoModel.selectedPaths())
            }
            Action {
                visible: !bar.privateMode
                icon: "copy"
                label: qsTr("Copy path")
                onTriggered: gallery.copyPaths(bar.photoModel.selectedPaths())
            }
            Action {
                visible: !bar.privateMode
                icon: "showFolder"
                label: qsTr("Show")
                onTriggered: gallery.showInFolder(bar.photoModel.selectedPaths()[0])
            }
            Action {
                visible: !bar.privateMode
                icon: "trash"
                label: qsTr("Delete")
                danger: true
                onTriggered: bar.win.confirmDelete(bar.photoModel.selectedPaths(), function() { bar.finished() })
            }
        }
    }
}
