import QtQuick
import ".."

// Sticky group header: a day ("Today", "Fri, Oct 23"), a month ("October", "May 2025") or
// a year ("2025") depending on the zoom level. Opaque so it covers rows.
Rectangle {
    id: header
    property string label: ""
    property bool selecting: false
    property bool checked: false
    property string level: "day"      // day | month | year
    signal toggle()

    height: Theme.sectionHeight
    color: Theme.bg

    Row {
        anchors.left: parent.left
        anchors.leftMargin: Theme.pageMargin - 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.s3

        CheckCircle {
            id: check
            anchors.verticalCenter: parent.verticalCenter
            onImage: false
            checked: header.checked
            visible: width > 1
            width: header.selecting ? 22 : 0
            opacity: header.selecting ? 1 : 0
            Behavior on width { NumberAnimation { duration: Theme.durNormal; easing.type: Theme.easing } }
            Behavior on opacity { NumberAnimation { duration: Theme.durNormal } }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: header.label
            color: Theme.text
            font.pixelSize: header.level === "year" ? Theme.fontTitle + 2
                          : header.level === "month" ? Theme.fontLarge + 1 : Theme.fontBody
            font.weight: header.level === "day" ? Font.DemiBold : Font.Bold
        }
    }
    MouseArea {
        anchors.fill: parent
        enabled: header.selecting
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: header.toggle()
    }
}
