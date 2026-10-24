import QtQuick
import QtQuick.Controls
import ".."

// Password sheet for the private album: "create" (set a password, typed twice), "unlock",
// or "change" (current + new). Calls onDone() after success.
Popup {
    id: dlg
    property string mode: "unlock"      // create | unlock | change
    property var onDone: null
    property string error: ""
    property bool working: privateAlbum.busy
    property int failures: 0
    property int waitSeconds: 0
    readonly property int minLength: 6

    function ask(m, done) {
        mode = m
        onDone = done || null
        error = ""
        current.text = ""
        first.text = ""
        second.text = ""
        open()
        Qt.callLater(function() { (mode === "change" ? current : first).forceActiveFocus() })
    }

    readonly property bool valid: {
        if (mode === "unlock") return first.text.length > 0 && waitSeconds === 0
        if (mode === "change" && current.text.length === 0) return false
        return first.text.length >= minLength && first.text === second.text
    }
    function submit() {
        if (!valid || working) return
        error = ""
        if (mode === "create") privateAlbum.create(first.text)
        else if (mode === "unlock") privateAlbum.unlock(first.text)
        else privateAlbum.changePassword(current.text, first.text)
    }
    function finished(ok, message) {
        if (!opened) return
        if (ok) {
            failures = 0
            var cb = onDone
            close()
            if (cb) cb()
            return
        }
        error = message
        if (mode === "unlock" && message.indexOf("Wrong") === 0) {
            failures++
            first.selectAll()
            if (failures >= 5) { waitSeconds = 30; cooldown.start() }   // slow down guessing
        }
    }
    Timer {
        id: cooldown
        interval: 1000
        repeat: true
        onTriggered: { dlg.waitSeconds--; if (dlg.waitSeconds <= 0) { stop(); dlg.failures = 0 } }
    }
    Connections {
        target: privateAlbum
        function onCreateFinished(ok, message) { if (dlg.mode === "create") dlg.finished(ok, message) }
        function onUnlockFinished(ok, message) { if (dlg.mode === "unlock") dlg.finished(ok, message) }
        function onPasswordChanged(ok, message) {
            if (dlg.mode !== "change") return
            dlg.finished(ok, message)
            if (ok) ApplicationWindow.window.showToast(qsTr("Password changed"))
        }
    }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(440, parent ? parent.width - 32 : 440)
    modal: true
    focus: true
    padding: Theme.s5
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    Overlay.modal: Rectangle { color: Theme.scrim }
    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durNormal }
        NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: Theme.durNormal; easing.type: Theme.easing }
    }
    exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: Theme.durFast } }
    background: Rectangle { radius: Theme.radiusL; color: Theme.surface }

    component PasswordField: Rectangle {
        id: field
        property alias text: input.text
        property string placeholder
        signal accepted()
        function forceActiveFocus() { input.forceActiveFocus() }
        function selectAll() { input.selectAll(); input.forceActiveFocus() }
        width: parent ? parent.width : 300
        height: 46
        radius: Theme.radiusS
        color: Theme.surfaceHigh
        border.width: input.activeFocus ? 2 : 0
        border.color: Theme.accent
        TextInput {
            id: input
            anchors.left: parent.left
            anchors.leftMargin: Theme.s3
            anchors.right: eye.left
            anchors.verticalCenter: parent.verticalCenter
            echoMode: eye.shown ? TextInput.Normal : TextInput.Password
            passwordCharacter: "•"
            color: Theme.text
            selectionColor: Theme.accent
            font.pixelSize: Theme.fontBody
            clip: true
            onAccepted: field.accepted()
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text.length === 0
                text: field.placeholder
                color: Theme.textSecondary
                font.pixelSize: Theme.fontBody
            }
        }
        IconButton {
            id: eye
            property bool shown: false
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            height: 40
            iconSize: 18
            icon: shown ? "eyeOff" : "eye"
            color: Theme.textSecondary
            tip: shown ? qsTr("Hide password") : qsTr("Show password")
            onClicked: shown = !shown
        }
    }

    contentItem: Column {
        spacing: Theme.s3

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 64
            height: 64
            radius: 32
            color: Theme.accentSoft
            Icon { anchors.centerIn: parent; name: "lock"; color: Theme.accent; size: 30 }
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: dlg.mode === "create" ? qsTr("Set up your private album")
                : dlg.mode === "change" ? qsTr("Change password") : qsTr("Private album")
            color: Theme.text
            font.pixelSize: Theme.fontLarge + 2
            font.weight: Font.Bold
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: dlg.mode === "create"
                  ? qsTr("Pictures and videos you move here are encrypted and removed from your folders. Only this password can open them.")
                  : dlg.mode === "change" ? qsTr("Your files stay as they are; only the password changes.")
                  : qsTr("Enter your password to open the private album.")
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSmall + 1
        }
        Item { width: 1; height: Theme.s1 }

        PasswordField {
            id: current
            visible: dlg.mode === "change"
            placeholder: qsTr("Current password")
            onAccepted: first.forceActiveFocus()
        }
        PasswordField {
            id: first
            placeholder: dlg.mode === "unlock" ? qsTr("Password")
                       : dlg.mode === "change" ? qsTr("New password") : qsTr("Password (at least %1 characters)").arg(dlg.minLength)
            onAccepted: dlg.mode === "unlock" ? dlg.submit() : second.forceActiveFocus()
        }
        PasswordField {
            id: second
            visible: dlg.mode !== "unlock"
            placeholder: qsTr("Type it again")
            onAccepted: dlg.submit()
        }
        Text {
            width: parent.width
            wrapMode: Text.Wrap
            visible: text !== ""
            text: dlg.waitSeconds > 0 ? qsTr("Too many tries. Wait %1 s.").arg(dlg.waitSeconds)
                : dlg.error !== "" ? dlg.error
                : dlg.mode !== "unlock" && second.text.length > 0 && first.text !== second.text ? qsTr("The passwords don't match")
                : dlg.mode !== "unlock" && first.text.length > 0 && first.text.length < dlg.minLength
                  ? qsTr("Use at least %1 characters").arg(dlg.minLength) : ""
            color: Theme.danger
            font.pixelSize: Theme.fontSmall
        }
        Rectangle {
            width: parent.width
            visible: dlg.mode === "create"
            height: warn.implicitHeight + 2 * Theme.s3
            radius: Theme.radiusS
            color: Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.1)
            Text {
                id: warn
                anchors.fill: parent
                anchors.margins: Theme.s3
                wrapMode: Text.Wrap
                text: qsTr("There is no way to recover a forgotten password. Without it, the files in the private album are lost.")
                color: Theme.text
                font.pixelSize: Theme.fontSmall
            }
        }
        Item { width: 1; height: Theme.s1 }
        Row {
            anchors.right: parent.right
            spacing: Theme.s2
            BusyIndicator {
                anchors.verticalCenter: parent.verticalCenter
                running: dlg.working
                visible: running
                width: 28
                height: 28
            }
            PillButton { kind: "text"; text: qsTr("Cancel"); onClicked: dlg.close() }
            PillButton {
                kind: "filled"
                enabled: dlg.valid && !dlg.working
                text: dlg.mode === "create" ? qsTr("Create") : dlg.mode === "change" ? qsTr("Change") : qsTr("Unlock")
                onClicked: dlg.submit()
            }
        }
    }
}
