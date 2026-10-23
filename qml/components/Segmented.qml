import QtQuick
import ".."

// Segmented choice control, e.g. System / Light / Dark.
Rectangle {
    id: seg
    property var options: []      // [{value, label}]
    property string value: ""
    signal picked(string value)

    readonly property int current: {
        for (var i = 0; i < options.length; ++i)
            if (options[i].value === value) return i
        return 0
    }
    implicitHeight: 40
    implicitWidth: 300
    radius: height / 2
    color: Theme.surfaceHigh

    Rectangle {
        width: (seg.width - 8) / Math.max(1, seg.options.length)
        height: seg.height - 8
        y: 4
        x: 4 + seg.current * width
        radius: height / 2
        color: Theme.surface
        Behavior on x { NumberAnimation { duration: Theme.durNormal; easing.type: Theme.easing } }
    }
    Row {
        x: 4
        y: 4
        Repeater {
            model: seg.options
            delegate: Item {
                required property var modelData
                required property int index
                width: (seg.width - 8) / Math.max(1, seg.options.length)
                height: seg.height - 8
                Text {
                    anchors.centerIn: parent
                    text: modelData.label
                    color: index === seg.current ? Theme.text : Theme.textSecondary
                    font.pixelSize: Theme.fontSmall + 1
                    font.weight: index === seg.current ? Font.DemiBold : Font.Normal
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: seg.picked(modelData.value)
                }
            }
        }
    }
}
