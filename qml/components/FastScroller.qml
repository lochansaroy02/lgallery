import QtQuick
import ".."

// Fast-scroll handle for long lists; shows a month/year bubble while dragging.
Item {
    id: scroller
    property ListView view
    property var labelForRow: function(row) { return "" }
    readonly property bool dragging: drag.pressed
    property bool shown: false

    width: 36
    visible: view && view.contentHeight > view.height * 2.5
    opacity: shown || dragging ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.durNormal } }

    Timer { id: hideTimer; interval: 1500; onTriggered: scroller.shown = false }
    Connections {
        target: scroller.view
        function onContentYChanged() {
            scroller.shown = true
            hideTimer.restart()
        }
    }

    readonly property real travel: height - handle.height
    property real dragRatio: 0
    readonly property real viewRatio: {
        if (!view) return 0
        var range = view.contentHeight - view.height
        return range > 0 ? Math.max(0, Math.min(1, (view.contentY - view.originY) / range)) : 0
    }

    Rectangle {
        id: handle
        anchors.right: parent.right
        anchors.rightMargin: 4
        width: scroller.dragging ? 10 : 6
        height: 56
        radius: width / 2
        y: (scroller.dragging ? scroller.dragRatio : scroller.viewRatio) * scroller.travel
        color: scroller.dragging ? Theme.accent : Theme.textSecondary
        opacity: scroller.dragging ? 1 : 0.7
        Behavior on width { NumberAnimation { duration: Theme.durFast } }
    }

    Rectangle {
        id: bubble
        visible: scroller.dragging && bubbleText.text !== ""
        anchors.right: handle.left
        anchors.rightMargin: 12
        y: Math.max(0, Math.min(scroller.height - height, handle.y + handle.height / 2 - height / 2))
        width: bubbleText.implicitWidth + 32
        height: 40
        radius: 20
        color: Theme.surface
        border.color: Theme.divider
        Text {
            id: bubbleText
            anchors.centerIn: parent
            color: Theme.text
            font.pixelSize: Theme.fontBody
            font.weight: Font.DemiBold
        }
    }

    MouseArea {
        id: drag
        anchors.right: parent.right
        width: 36
        height: parent.height
        cursorShape: Qt.SizeVerCursor
        preventStealing: true
        hoverEnabled: true
        onEntered: { scroller.shown = true; hideTimer.restart() }
        function update(y) {
            scroller.dragRatio = Math.max(0, Math.min(1, (y - handle.height / 2) / scroller.travel))
            var count = scroller.view.count
            if (count <= 0) return
            var row = Math.round(scroller.dragRatio * (count - 1))
            scroller.view.positionViewAtIndex(row, ListView.Beginning)
            if (scroller.dragRatio <= 0) scroller.view.positionViewAtBeginning()
            if (scroller.dragRatio >= 1) scroller.view.positionViewAtEnd()
            bubbleText.text = scroller.labelForRow(row)
        }
        onPressed: (m) => { scroller.dragRatio = scroller.viewRatio; update(m.y) }
        onPositionChanged: (m) => { if (pressed) update(m.y) }
        onReleased: hideTimer.restart()
    }
}
