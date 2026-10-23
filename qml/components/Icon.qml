import QtQuick
import QtQuick.Shapes
import ".."
import "icons.js" as Icons

// Vector icon drawn with Shapes so it follows the theme colour at any size.
Item {
    id: icon
    property string name: "image"
    property color color: Theme.text
    property real size: 24
    property bool filled: false
    property real strokeWidth: 2

    implicitWidth: size
    implicitHeight: size

    Shape {
        width: 24
        height: 24
        anchors.centerIn: parent
        scale: icon.size / 24
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: icon.color
            strokeWidth: icon.strokeWidth
            fillColor: icon.filled ? icon.color : "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: Icons.paths[icon.name] || Icons.paths["image"] }
        }
    }
}
