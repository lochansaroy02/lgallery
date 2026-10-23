import QtQuick
import QtQuick.Controls
import ".."

// Rounded One UI style confirmation dialog: ask(title, message, actionText, onAccept)
Popup {
    id: dlg
    property string title
    property string message
    property string actionText: qsTr("Delete")
    property bool destructive: true
    property var onAccept: null

    function ask(t, m, action, cb, isDestructive) {
        title = t
        message = m
        actionText = action || qsTr("OK")
        destructive = isDestructive === undefined ? true : isDestructive
        onAccept = cb
        open()
    }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(420, parent ? parent.width - 48 : 420)
    modal: true
    focus: true
    padding: Theme.s5
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    Overlay.modal: Rectangle { color: Theme.scrim }
    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durNormal }
        NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: Theme.durNormal; easing.type: Theme.easing }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; to: 0; duration: Theme.durFast }
    }
    background: Rectangle { radius: Theme.radiusL; color: Theme.surface }

    contentItem: Column {
        spacing: Theme.s3
        focus: true
        Keys.onReturnPressed: { var cb = dlg.onAccept; dlg.close(); if (cb) cb() }
        Text {
            width: parent.width
            text: dlg.title
            wrapMode: Text.Wrap
            color: Theme.text
            font.pixelSize: Theme.fontLarge + 1
            font.weight: Font.Bold
        }
        Text {
            width: parent.width
            visible: text !== ""
            text: dlg.message
            wrapMode: Text.Wrap
            color: Theme.textSecondary
            font.pixelSize: Theme.fontBody
        }
        Item { width: 1; height: Theme.s2 }
        Row {
            anchors.right: parent.right
            spacing: Theme.s2
            PillButton {
                kind: "text"
                text: qsTr("Cancel")
                onClicked: dlg.close()
            }
            PillButton {
                kind: dlg.destructive ? "danger" : "filled"
                text: dlg.actionText
                onClicked: {
                    var cb = dlg.onAccept
                    dlg.close()
                    if (cb) cb()
                }
            }
        }
    }
}
