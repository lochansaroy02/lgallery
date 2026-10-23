import QtQuick
import QtQuick.Controls
import ".."

// Accent colour choice: "System" (KDE's accent colour), a palette, and a custom colour.
Column {
    id: picker
    spacing: Theme.s3
    readonly property bool usingSystem: prefs.accent === "system"
    readonly property bool customChosen: !usingSystem
        && !Theme.accentPalette.some(p => p.color === prefs.accent)

    component Swatch: Item {
        id: swatch
        property color fill: "transparent"
        property bool selected: false
        property string tip: ""
        property string glyph: ""          // icon drawn in the middle (System / Custom)
        signal picked()
        width: 40
        height: 40
        Rectangle {
            anchors.centerIn: parent
            width: swatch.selected ? 40 : 32
            height: width
            radius: width / 2
            color: "transparent"
            border.width: swatch.selected ? 2.5 : 0
            border.color: swatch.fill
            Behavior on width { NumberAnimation { duration: Theme.durFast } }
        }
        Rectangle {
            anchors.centerIn: parent
            width: 30
            height: 30
            radius: 15
            color: swatch.fill
            border.width: swatch.glyph === "plus" ? 1.5 : 0
            border.color: Theme.divider
            scale: mouse.pressed ? 0.9 : (mouse.containsMouse ? 1.08 : 1)
            Behavior on scale { NumberAnimation { duration: Theme.durFast } }
            Icon {
                anchors.centerIn: parent
                visible: swatch.selected || swatch.glyph !== ""
                name: swatch.selected ? "check" : swatch.glyph
                size: 16
                strokeWidth: 2.6
                color: swatch.glyph === "plus" && !swatch.selected ? Theme.textSecondary
                       : (0.2126 * swatch.fill.r + 0.7152 * swatch.fill.g + 0.0722 * swatch.fill.b > 0.62 ? "#111114" : "white")
            }
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: swatch.picked()
        }
        ToolTip.visible: tip !== "" && mouse.containsMouse
        ToolTip.delay: 400
        ToolTip.text: tip
    }

    Flow {
        width: parent.width
        spacing: Theme.s2
        Swatch {
            fill: ApplicationWindow.window ? ApplicationWindow.window.systemAccent : Theme.defaultAccent
            selected: picker.usingSystem
            glyph: picker.usingSystem ? "" : "sun"
            tip: qsTr("System: use KDE's accent colour (follows the wallpaper if you chose that)")
            onPicked: prefs.accent = "system"
        }
        Rectangle { width: 1; height: 28; y: 6; color: Theme.divider }
        Repeater {
            model: Theme.accentPalette
            delegate: Swatch {
                required property var modelData
                fill: modelData.color
                selected: prefs.accent === modelData.color
                tip: modelData.name
                onPicked: prefs.accent = modelData.color
            }
        }
        Swatch {
            visible: picker.customChosen
            fill: picker.customChosen ? prefs.accent : "transparent"
            selected: true
            tip: qsTr("Custom colour %1").arg(prefs.accent)
            onPicked: ApplicationWindow.window.pickCustomAccent()
        }
        Swatch {
            fill: "transparent"
            glyph: "plus"
            tip: qsTr("Custom colour…")
            onPicked: ApplicationWindow.window.pickCustomAccent()
        }
    }
}
