import QtQuick
import QtQuick.Controls
import ".."

// "Same person as…": pick another person to merge into. ask(personId, callback(targetId))
Popup {
    id: dlg
    property int personId: -1
    property var onPick: null
    readonly property var others: collections.people.filter(p => p.id !== personId)
    function ask(id, callback) { personId = id; onPick = callback; open() }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(560, parent ? parent.width - 48 : 560)
    height: Math.min(560, parent ? parent.height - 48 : 560)
    modal: true
    focus: true
    padding: Theme.s5
    Overlay.modal: Rectangle { color: Theme.scrim }
    background: Rectangle { radius: Theme.radiusL; color: Theme.surface }
    contentItem: Column {
        spacing: Theme.s3
        Text {
            text: qsTr("Same person as…")
            color: Theme.text
            font.pixelSize: Theme.fontLarge + 1
            font.weight: Font.Bold
        }
        Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: qsTr("Pick the person these pictures belong to. Their pictures are combined.")
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSmall + 1
        }
        GridView {
            id: grid
            width: parent.width
            height: dlg.availableHeight - 120
            clip: true
            cellWidth: width / Math.max(3, Math.floor(width / 120))
            cellHeight: 150
            model: dlg.others
            delegate: Item {
                required property var modelData
                width: grid.cellWidth
                height: grid.cellHeight
                PersonAvatar {
                    anchors.horizontalCenter: parent.horizontalCenter
                    size: 80
                    maskColor: Theme.surface
                    person: modelData
                    onClicked: { var cb = dlg.onPick; dlg.close(); if (cb) cb(modelData.id) }
                }
            }
        }
        PillButton { anchors.right: parent.right; kind: "text"; text: qsTr("Cancel"); onClicked: dlg.close() }
    }
}
