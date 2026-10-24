import QtQuick
import QtQuick.Controls
import ".."

// Thin separator for StyledMenu; collapses when hidden.
MenuSeparator {
    height: visible ? implicitHeight : 0
    topPadding: 4
    bottomPadding: 4
    contentItem: Rectangle { implicitHeight: 1; implicitWidth: 260; color: Theme.divider }
}
