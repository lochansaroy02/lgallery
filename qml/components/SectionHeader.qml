import QtQuick
import ".."

// Sticky day header ("Today", "Yesterday", "Fri, Oct 23"). Opaque so it covers rows.
Rectangle {
    id: header
    property string label: ""
    property bool selecting: false
    property bool checked: false
    signal toggle()

    height: Theme.sectionHeight
    color: Theme.bg

    Row {
        anchors.left: parent.left
        anchors.leftMargin: Theme.pageMargin - 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.s3

        CheckCircle {
            id: check
            anchors.verticalCenter: parent.verticalCenter
            onImage: false
            checked: header.checked
            visible: width > 1
            width: header.selecting ? 22 : 0
            opacity: header.selecting ? 1 : 0
            Behavior on width { NumberAnimation { duration: Theme.durNormal; easing.type: Theme.easing } }
            Behavior on opacity { NumberAnimation { duration: Theme.durNormal } }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: header.label
            color: Theme.text
            font.pixelSize: Theme.fontBody
            font.weight: Font.DemiBold
        }
    }
    MouseArea {
        anchors.fill: parent
        enabled: header.selecting
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: header.toggle()
    }
}
