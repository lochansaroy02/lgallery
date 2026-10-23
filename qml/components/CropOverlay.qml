import QtQuick
import ".."

// Crop box drawn over the (uncropped) editor preview. Works in pixels while
// dragging and reports the normalised rectangle on release.
Item {
    id: ov
    property var crop: [0, 0, 1, 1]
    property real aspect: 0              // width / height in pixels, 0 = free
    signal committed(real x, real y, real w, real h)

    property real rx: 0
    property real ry: 0
    property real rw: width
    property real rh: height
    property bool dragging: false
    readonly property real minSize: 40

    function sync() {
        if (!crop || crop.length !== 4) return
        rx = crop[0] * width; ry = crop[1] * height
        rw = crop[2] * width; rh = crop[3] * height
    }
    onCropChanged: if (!dragging) sync()
    onWidthChanged: sync()
    onHeightChanged: sync()
    Component.onCompleted: sync()

    function commit() {
        dragging = false
        if (width > 0 && height > 0) committed(rx / width, ry / height, rw / width, rh / height)
    }

    // drag a corner: (ax, ay) is the fixed opposite corner, (px, py) the pointer
    function dragCorner(ax, ay, px, py) {
        px = Math.max(0, Math.min(width, px)); py = Math.max(0, Math.min(height, py))
        var w = Math.max(minSize, Math.abs(px - ax)), h = Math.max(minSize, Math.abs(py - ay))
        if (aspect > 0) {
            if (w / h > aspect) w = h * aspect
            else h = w / aspect
        }
        var left = px < ax, up = py < ay
        w = Math.min(w, left ? ax : width - ax)
        h = Math.min(h, up ? ay : height - ay)
        if (aspect > 0) { if (w / h > aspect) w = h * aspect; else h = w / aspect }
        rx = left ? ax - w : ax; ry = up ? ay - h : ay; rw = w; rh = h
    }

    // dimmed area outside the crop box
    Rectangle { x: 0; y: 0; width: ov.width; height: ov.ry; color: "#99000000" }
    Rectangle { x: 0; y: ov.ry + ov.rh; width: ov.width; height: ov.height - ov.ry - ov.rh; color: "#99000000" }
    Rectangle { x: 0; y: ov.ry; width: ov.rx; height: ov.rh; color: "#99000000" }
    Rectangle { x: ov.rx + ov.rw; y: ov.ry; width: ov.width - ov.rx - ov.rw; height: ov.rh; color: "#99000000" }

    Item {
        id: box
        x: ov.rx; y: ov.ry; width: ov.rw; height: ov.rh
        Rectangle { anchors.fill: parent; color: "transparent"; border.color: "white"; border.width: 1.5 }
        // rule-of-thirds grid while dragging
        Repeater {
            model: 2
            Rectangle { visible: ov.dragging; x: box.width * (index + 1) / 3; width: 1; height: box.height; color: "#88FFFFFF" }
        }
        Repeater {
            model: 2
            Rectangle { visible: ov.dragging; y: box.height * (index + 1) / 3; height: 1; width: box.width; color: "#88FFFFFF" }
        }
        // move the whole box
        MouseArea {
            anchors.fill: parent
            anchors.margins: 22
            cursorShape: Qt.SizeAllCursor
            preventStealing: true
            property real sx; property real sy; property real ox; property real oy
            onPressed: (m) => { var p = mapToItem(ov, m.x, m.y); sx = p.x; sy = p.y; ox = ov.rx; oy = ov.ry; ov.dragging = true }
            onPositionChanged: (m) => {
                var p = mapToItem(ov, m.x, m.y)
                ov.rx = Math.max(0, Math.min(ov.width - ov.rw, ox + p.x - sx))
                ov.ry = Math.max(0, Math.min(ov.height - ov.rh, oy + p.y - sy))
            }
            onReleased: ov.commit()
        }
    }

    // corner handles: [x side, y side] 0 = left/top, 1 = right/bottom
    Repeater {
        model: [[0, 0], [1, 0], [0, 1], [1, 1]]
        delegate: Item {
            required property var modelData
            readonly property int sxSide: modelData[0]
            readonly property int sySide: modelData[1]
            width: 44; height: 44
            x: ov.rx + sxSide * ov.rw - 22
            y: ov.ry + sySide * ov.rh - 22
            Rectangle { x: sxSide ? 22 - 20 : 22 - 2; y: sySide ? 22 - 2 : 22 - 2; width: 22; height: 4; color: "white" }
            Rectangle { x: 22 - 2; y: sySide ? 22 - 20 : 22 - 2; width: 4; height: 22; color: "white" }
            MouseArea {
                anchors.fill: parent
                preventStealing: true
                cursorShape: (sxSide === sySide) ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
                property real ax; property real ay
                onPressed: {
                    ax = sxSide ? ov.rx : ov.rx + ov.rw
                    ay = sySide ? ov.ry : ov.ry + ov.rh
                    ov.dragging = true
                }
                onPositionChanged: (m) => { var p = mapToItem(ov, m.x, m.y); ov.dragCorner(ax, ay, p.x, p.y) }
                onReleased: ov.commit()
            }
        }
    }

    // edge handles (free aspect only)
    Repeater {
        model: ov.aspect > 0 ? [] : ["left", "right", "top", "bottom"]
        delegate: MouseArea {
            required property string modelData
            readonly property bool vertical: modelData === "left" || modelData === "right"
            width: vertical ? 30 : Math.max(0, ov.rw - 60)
            height: vertical ? Math.max(0, ov.rh - 60) : 30
            x: modelData === "left" ? ov.rx - 15 : modelData === "right" ? ov.rx + ov.rw - 15 : ov.rx + 30
            y: modelData === "top" ? ov.ry - 15 : modelData === "bottom" ? ov.ry + ov.rh - 15 : ov.ry + 30
            preventStealing: true
            cursorShape: vertical ? Qt.SizeHorCursor : Qt.SizeVerCursor
            onPressed: ov.dragging = true
            onPositionChanged: (m) => {
                var p = mapToItem(ov, m.x, m.y)
                if (modelData === "left") {
                    var right = ov.rx + ov.rw
                    ov.rx = Math.max(0, Math.min(right - ov.minSize, p.x)); ov.rw = right - ov.rx
                } else if (modelData === "right") {
                    ov.rw = Math.max(ov.minSize, Math.min(ov.width - ov.rx, p.x - ov.rx))
                } else if (modelData === "top") {
                    var bottom = ov.ry + ov.rh
                    ov.ry = Math.max(0, Math.min(bottom - ov.minSize, p.y)); ov.rh = bottom - ov.ry
                } else {
                    ov.rh = Math.max(ov.minSize, Math.min(ov.height - ov.ry, p.y - ov.ry))
                }
            }
            onReleased: ov.commit()
            Rectangle {
                anchors.centerIn: parent
                width: parent.vertical ? 4 : 24
                height: parent.vertical ? 24 : 4
                radius: 2
                color: "white"
            }
        }
    }
}
