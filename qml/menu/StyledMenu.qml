import QtQuick
import QtQuick.Controls
import ".."

// Rounded, theme-coloured Qt Quick menu used for the in-app ⋮ menu and its submenus.
Menu {
    id: menu
    padding: 6
    overlap: 6
    cascade: true
    delegate: AppMenuItem { }
    background: Rectangle {
        implicitWidth: 280
        radius: Theme.radiusM
        color: Theme.surface
        border.color: Theme.divider
        border.width: 1
    }
    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durFast }
        NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: Theme.durFast; easing.type: Theme.easing }
    }
    exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 100 } }
}
