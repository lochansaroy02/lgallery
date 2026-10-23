import QtQuick
import QtQuick.Shapes
import ".."

// Image with rounded corners. Instead of a shader mask it paints the four corner
// cut-outs in the background colour, which is cheap and works on every renderer
// (including software rendering) as long as it sits on a solid background.
Item {
    id: root
    property alias source: img.source
    property alias status: img.status
    property real radius: 20
    property color maskColor: Theme.bg
    property int fillMode: Image.PreserveAspectCrop

    Image {
        id: img
        anchors.fill: parent
        asynchronous: true
        fillMode: root.fillMode
        mipmap: true
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }
    Shape {
        id: corners
        anchors.fill: parent
        anchors.margins: -1   // overlap the edge so no anti-aliased seam shows
        visible: root.radius > 0
        preferredRendererType: Shape.CurveRenderer
        readonly property real r: Math.min(root.radius + 1, width / 2, height / 2)
        ShapePath {
            strokeColor: "transparent"
            fillColor: root.maskColor
            PathSvg {
                property real r: corners.r
                property real w: corners.width
                property real h: corners.height
                path: "M0 0H" + r + "A" + r + " " + r + " 0 0 0 0 " + r + "Z"
                    + "M" + w + " 0V" + r + "A" + r + " " + r + " 0 0 0 " + (w - r) + " 0Z"
                    + "M" + w + " " + h + "H" + (w - r) + "A" + r + " " + r + " 0 0 0 " + w + " " + (h - r) + "Z"
                    + "M0 " + h + "V" + (h - r) + "A" + r + " " + r + " 0 0 0 " + r + " " + h + "Z"
            }
        }
    }
}
