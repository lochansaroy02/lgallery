import QtQuick
import ".."

// One UI style rounded button. kind: "filled" | "tonal" | "text" | "danger"
Rectangle {
    id: btn
    property string text: ""
    property string icon: ""
    property string kind: "filled"
    property bool compact: false
    signal clicked()

    readonly property color fg: kind === "filled" ? Theme.accentText
                              : kind === "danger" ? Theme.danger
                              : Theme.accent
    implicitHeight: compact ? 38 : 46
    implicitWidth: row.implicitWidth + (compact ? 32 : 44)
    radius: height / 2
    opacity: enabled ? 1 : 0.4
    color: {
        var base = kind === "filled" ? Theme.accent : kind === "tonal" ? Theme.accentSoft : "transparent"
        if (mouse.pressed) return kind === "filled" ? Qt.darker(Theme.accent, 1.15) : Theme.pressed
        if (mouse.containsMouse) return kind === "filled" ? Qt.lighter(Theme.accent, 1.08)
                                      : kind === "tonal" ? Qt.darker(Theme.accentSoft, 1.05) : Theme.hover
        return base
    }
    Behavior on color { ColorAnimation { duration: Theme.durFast } }
    scale: mouse.pressed ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: Theme.durFast } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.s2
        Icon {
            visible: btn.icon !== ""
            name: btn.icon
            color: btn.fg
            size: 20
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: btn.text
            color: btn.fg
            font.pixelSize: btn.compact ? Theme.fontSmall + 1 : Theme.fontBody
            font.weight: Font.DemiBold
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
