import QtQuick
import ".."

// One square grid cell. `item` = {index, src, selected, available, favorite}
Item {
    id: thumb
    property var item: ({})
    property bool selecting: false
    readonly property bool selected: selecting && item && item.selected === true
    readonly property alias image: img
    signal activated(int index, int modifiers)
    signal longPressed(int index)
    signal contextRequested(int index)

    Rectangle {
        id: frame
        anchors.fill: parent
        color: Theme.placeholder
        radius: thumb.selected ? Theme.selectedThumbRadius : Theme.thumbRadius
        scale: thumb.selected ? 0.9 : (mouse.pressed ? 0.97 : 1)
        clip: radius === 0
        Behavior on scale { NumberAnimation { duration: Theme.durNormal; easing.type: Theme.easing } }
        Behavior on radius { NumberAnimation { duration: Theme.durNormal } }

        Image {
            id: img
            anchors.fill: parent
            source: thumb.item && thumb.item.src ? thumb.item.src : ""
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            smooth: true
            mipmap: true
            opacity: status === Image.Ready ? (thumb.item.available ? 1 : 0.45) : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
            visible: frame.radius === 0
        }
        // rounded variant while selected (no clipping of rounded rects in plain QtQuick)
        RoundedImage {
            anchors.fill: parent
            visible: frame.radius > 0
            source: visible ? img.source : ""
            radius: frame.radius
            maskColor: Theme.bg
        }
        Icon {
            anchors.centerIn: parent
            visible: img.status === Image.Error
            name: "broken"
            color: Theme.textSecondary
            size: Math.min(28, parent.width / 3)
        }
        Icon {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 6
            visible: thumb.item && thumb.item.available === false
            name: "unavailable"
            color: "white"
            size: 16
        }
        Icon {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 6
            visible: thumb.item && thumb.item.favorite === true && !thumb.selecting
            name: "heart"
            filled: true
            color: "white"
            size: 14
        }
    }

    CheckCircle {
        x: 8
        y: 8
        checked: thumb.selected
        opacity: thumb.selecting ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.durNormal } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        pressAndHoldInterval: 450
        cursorShape: Qt.PointingHandCursor
        onClicked: (m) => {
            if (m.button === Qt.RightButton)
                thumb.contextRequested(thumb.item.index)
            else
                thumb.activated(thumb.item.index, m.modifiers)
        }
        onPressAndHold: (m) => { if (m.button === Qt.LeftButton) thumb.longPressed(thumb.item.index) }
    }
}
