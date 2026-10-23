import QtQuick
import QtQuick.Controls
import ".."

// Share menu with the same targets as Dolphin's "Share" submenu (KDE Purpose):
// KDE Connect, Bluetooth, e-mail, Telegram, Imgur, Nextcloud, ...
Popup {
    id: menu
    property var paths: []
    property var onShared: null

    // anchor: the button the menu belongs to; it opens above it (or below if no room)
    function openFor(filePaths, anchor, callback) {
        paths = filePaths
        onShared = callback || null
        gallery.prepareShare(filePaths)
        place(anchor)
        open()
    }
    function place(anchor) {
        var host = parent
        if (!anchor || !host) { x = (host.width - width) / 2; y = (host.height - height) / 2; return }
        var p = anchor.mapToItem(host, anchor.width / 2, 0)
        x = Math.max(12, Math.min(host.width - width - 12, p.x - width / 2))
        var above = p.y - height - 10
        y = above >= 12 ? above : Math.min(host.height - height - 12, p.y + anchor.height + 10)
    }
    function pick(id) {
        var cb = onShared
        close()
        gallery.shareWith(id, paths)
        if (cb) cb()
    }

    parent: Overlay.overlay
    width: 310
    height: Math.min(content.implicitHeight + topPadding + bottomPadding, parent ? parent.height - 24 : 600)
    padding: Theme.s2
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    onHeightChanged: if (opened) Qt.callLater(function() { y = Math.max(12, Math.min(y, parent.height - height - 12)) })

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durFast }
        NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: Theme.durNormal; easing.type: Theme.easing }
    }
    exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: Theme.durFast } }
    background: Rectangle {
        radius: Theme.radiusL
        color: Theme.surface
        border.color: Theme.divider
        border.width: 1
    }

    component ShareRow: Rectangle {
        id: row
        property string label
        property string themeIcon: ""
        property string fallbackIcon: "share"
        signal clicked()
        width: content.width
        height: 46
        radius: Theme.radiusS
        color: rowMouse.pressed ? Theme.pressed : rowMouse.containsMouse ? Theme.hover : "transparent"
        Item {
            id: iconBox
            x: Theme.s3
            width: 24
            height: 24
            anchors.verticalCenter: parent.verticalCenter
            Image {
                id: themed
                anchors.fill: parent
                source: row.themeIcon !== "" ? "image://icon/" + row.themeIcon : ""
                sourceSize: Qt.size(48, 48)
                visible: status === Image.Ready && implicitWidth > 1
            }
            Icon {
                anchors.centerIn: parent
                visible: !themed.visible
                name: row.fallbackIcon
                size: 20
                color: Theme.text
            }
        }
        Text {
            anchors.left: iconBox.right
            anchors.leftMargin: Theme.s3
            anchors.right: parent.right
            anchors.rightMargin: Theme.s3
            anchors.verticalCenter: parent.verticalCenter
            text: row.label
            elide: Text.ElideRight
            color: Theme.text
            font.pixelSize: Theme.fontBody
        }
        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.clicked()
        }
    }

    contentItem: Flickable {
        clip: true
        contentHeight: content.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        implicitHeight: content.implicitHeight

        Column {
            id: content
            width: parent.width
            spacing: 2

            Text {
                leftPadding: Theme.s3
                topPadding: Theme.s1
                bottomPadding: Theme.s2
                text: menu.paths.length === 1 ? qsTr("Share") : qsTr("Share %1 pictures").arg(menu.paths.length)
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSmall
                font.weight: Font.DemiBold
            }
            ShareRow {
                label: qsTr("Copy to Clipboard")
                themeIcon: "edit-copy"
                fallbackIcon: "copy"
                onClicked: menu.pick("")
            }
            Repeater {
                model: gallery.shareTargets
                delegate: ShareRow {
                    required property var modelData
                    label: modelData.name
                    themeIcon: modelData.icon || ""
                    onClicked: menu.pick(modelData.id)
                }
            }
            Item {
                width: content.width
                height: 46
                visible: gallery.shareLoading
                Row {
                    x: Theme.s3
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.s3
                    BusyIndicator { width: 24; height: 24; running: parent.parent.visible }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Loading share options…")
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSmall + 1
                    }
                }
            }
            Text {
                width: content.width
                visible: !gallery.shareAvailable
                leftPadding: Theme.s3
                rightPadding: Theme.s3
                topPadding: Theme.s2
                bottomPadding: Theme.s2
                wrapMode: Text.Wrap
                text: qsTr("More options (KDE Connect, Bluetooth, e-mail…) need KDE's sharing framework: sudo pacman -S purpose")
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSmall
            }
        }
    }
}
