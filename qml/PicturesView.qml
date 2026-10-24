import QtQuick
import QtQuick.Controls
import "."
import "components"

// Main "Pictures" tab: every indexed picture and video, newest first, grouped by day.
PhotoGrid {
    id: pictures
    photoModel: photos
    title: qsTr("Pictures")
    busy: gallery.scanning
    showSettingsButton: true
    subtitle: gallery.scanning
              ? qsTr("Scanning… %1 found").arg(gallery.scanFound.toLocaleString(Qt.locale(), "f", 0))
              : countText(photos.itemCount)
    emptyState: !gallery.hasFolders ? welcome : (gallery.scanning ? scanningState : nothingFound)

    Component {
        id: welcome
        Column {
            spacing: Theme.s4
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 104
                height: 104
                radius: 52
                color: Theme.accentSoft
                Icon { anchors.centerIn: parent; name: "pictures"; color: Theme.accent; size: 48 }
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Your gallery is empty")
                color: Theme.text
                font.pixelSize: Theme.fontTitle + 2
                font.weight: Font.Bold
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: qsTr("Choose the folders to show here, including folders on other drives. Your files stay where they are.")
                color: Theme.textSecondary
                font.pixelSize: Theme.fontBody
            }
            Item { width: 1; height: Theme.s2 }
            PillButton {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Add folder")
                icon: "folderPlus"
                onClicked: ApplicationWindow.window.addFolder()
            }
            PillButton {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: gallery.suggestedFolder !== ""
                kind: "tonal"
                text: qsTr("Add %1").arg(gallery.suggestedFolder.replace(/^.*[\/\\]/, ""))
                icon: "plus"
                onClicked: gallery.addFolder(gallery.suggestedFolder)
            }
        }
    }
    Component {
        id: scanningState
        Column {
            spacing: Theme.s3
            BusyIndicator { anchors.horizontalCenter: parent.horizontalCenter; running: true }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Looking for pictures…")
                color: Theme.textSecondary
                font.pixelSize: Theme.fontBody
            }
        }
    }
    Component {
        id: nothingFound
        Column {
            spacing: Theme.s3
            Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "pictures"; color: Theme.textSecondary; size: 44 }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: qsTr("No pictures found in your folders yet.")
                color: Theme.textSecondary
                font.pixelSize: Theme.fontBody
            }
        }
    }
}
