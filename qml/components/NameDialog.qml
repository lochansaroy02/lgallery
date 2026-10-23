import QtQuick
import QtQuick.Controls
import ".."

// Ask for a person's name: ask(currentName, callback(name))
Popup {
    id: dlg
    property var onAccept: null
    function ask(current, callback) {
        field.text = current || ""
        onAccept = callback
        open()
        field.forceActiveFocus()
        field.selectAll()
    }
    function accept() {
        var cb = onAccept
        var name = field.text.trim()
        close()
        if (cb) cb(name)
    }
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(400, parent ? parent.width - 48 : 400)
    modal: true
    focus: true
    padding: Theme.s5
    Overlay.modal: Rectangle { color: Theme.scrim }
    background: Rectangle { radius: Theme.radiusL; color: Theme.surface }
    contentItem: Column {
        spacing: Theme.s4
        Text {
            text: qsTr("Who is this?")
            color: Theme.text
            font.pixelSize: Theme.fontLarge + 1
            font.weight: Font.Bold
        }
        TextField {
            id: field
            width: parent.width
            placeholderText: qsTr("Name")
            color: Theme.text
            placeholderTextColor: Theme.textSecondary
            font.pixelSize: Theme.fontBody
            selectByMouse: true
            background: Rectangle { radius: Theme.radiusS; color: Theme.surfaceHigh; implicitHeight: 44 }
            leftPadding: Theme.s3
            onAccepted: dlg.accept()
        }
        Row {
            anchors.right: parent.right
            spacing: Theme.s2
            PillButton { kind: "text"; text: qsTr("Cancel"); onClicked: dlg.close() }
            PillButton { text: qsTr("Save"); onClicked: dlg.accept() }
        }
    }
}
