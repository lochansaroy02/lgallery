import QtQuick
import QtQuick.Controls
import "."
import "components"

// "Videos" tab: every indexed video, newest first, grouped by day like Pictures.
PhotoGrid {
    id: videosGrid
    photoModel: videos
    title: qsTr("Videos")
    busy: gallery.scanning
    showSettingsButton: true
    subtitle: videos.itemCount === 1 ? qsTr("1 video")
                                     : qsTr("%1 videos").arg(videos.itemCount.toLocaleString(Qt.locale(), "f", 0))
    emptyState: noVideos

    Component {
        id: noVideos
        Column {
            spacing: Theme.s4
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 104
                height: 104
                radius: 52
                color: Theme.accentSoft
                Icon { anchors.centerIn: parent; name: "video"; color: Theme.accent; size: 48 }
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: gallery.scanning ? qsTr("Looking for videos…") : qsTr("No videos yet")
                color: Theme.text
                font.pixelSize: Theme.fontTitle + 2
                font.weight: Font.Bold
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: gallery.hasFolders
                      ? qsTr("Videos (MP4, MOV, MKV, WebM, AVI…) in your folders show up here and among your pictures.")
                      : qsTr("Add a folder to see its videos here.")
                color: Theme.textSecondary
                font.pixelSize: Theme.fontBody
            }
            Text {
                width: parent.width
                visible: !gallery.videoThumbnailsSupported
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: qsTr("Install ffmpeg for video thumbnails: sudo pacman -S ffmpeg")
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSmall
            }
            Item { width: 1; height: Theme.s2 }
            PillButton {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !gallery.hasFolders
                text: qsTr("Add folder")
                icon: "folderPlus"
                onClicked: ApplicationWindow.window.addFolder()
            }
        }
    }
}
