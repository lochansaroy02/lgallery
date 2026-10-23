import QtQuick
import ".."

// Small snackbar shown above the navigation bar.
Rectangle {
    id: toast
    function show(message) {
        label.text = message
        opacity = 1
        timer.restart()
    }
    width: Math.min(label.implicitWidth + 48, (parent ? parent.width : 600) - 48)
    height: label.implicitHeight + 24
    radius: height / 2
    color: Theme.toastBg
    opacity: 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Theme.durNormal } }
    Text {
        id: label
        anchors.centerIn: parent
        width: Math.min(implicitWidth, toast.width - 40)
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        color: "white"
        font.pixelSize: Theme.fontSmall + 1
    }
    Timer { id: timer; interval: 2800; onTriggered: toast.opacity = 0 }
}
