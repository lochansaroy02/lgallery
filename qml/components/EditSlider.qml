import QtQuick
import ".."

// Editor slider. Centred sliders (from < 0) fill from zero and snap to it.
// The value is owned by the caller: bind `value`, update it from `moved`.
Item {
    id: s
    property real from: -100
    property real to: 100
    property real value: 0
    property string valueText: (value > 0.5 ? "+" : "") + Math.round(value)
    readonly property bool centered: from < 0
    readonly property bool pressed: area.pressed
    signal moved(real value)
    signal released()
    signal reset()

    implicitHeight: 56
    readonly property real pos: Math.max(0, Math.min(1, (value - from) / (to - from)))
    readonly property real zeroPos: centered ? -from / (to - from) : 0

    Text {
        anchors.horizontalCenter: handle.horizontalCenter
        anchors.bottom: track.top
        anchors.bottomMargin: 14
        text: s.valueText
        color: s.pressed ? "white" : "#9A9AA0"
        font.pixelSize: Theme.fontSmall
        font.weight: Font.DemiBold
    }
    Rectangle {
        id: track
        x: 14
        width: parent.width - 28
        y: parent.height - 18
        height: 4
        radius: 2
        color: "#3A3A3C"
    }
    Rectangle {
        x: track.x + track.width * Math.min(s.pos, s.zeroPos)
        width: track.width * Math.abs(s.pos - s.zeroPos)
        y: track.y
        height: track.height
        radius: 2
        color: Theme.accent
    }
    Rectangle {
        visible: s.centered
        x: track.x + track.width * s.zeroPos - 1
        y: track.y - 5
        width: 2
        height: 14
        radius: 1
        color: "#6E6E73"
    }
    Rectangle {
        id: handle
        width: s.pressed ? 26 : 22
        height: width
        radius: width / 2
        x: track.x + track.width * s.pos - width / 2
        y: track.y + track.height / 2 - height / 2
        color: "white"
        Behavior on width { NumberAnimation { duration: Theme.durFast } }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        function update(mx) {
            var p = Math.max(0, Math.min(1, (mx - track.x) / track.width))
            var v = s.from + p * (s.to - s.from)
            if (s.centered && Math.abs(v) < (s.to - s.from) * 0.012) v = 0
            s.moved(v)
        }
        onPressed: (m) => update(m.x)
        onPositionChanged: (m) => { if (pressed) update(m.x) }
        onReleased: s.released()
        onDoubleClicked: s.reset()
    }
    WheelHandler {
        target: null
        onWheel: (ev) => {
            var step = (s.to - s.from) / 100 * (ev.angleDelta.y > 0 ? 1 : -1)
            s.moved(Math.max(s.from, Math.min(s.to, s.value + step)))
            s.released()
        }
    }
}
