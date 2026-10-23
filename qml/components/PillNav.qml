import QtQuick
import QtQuick.Effects
import ".."

// Floating pill-shaped bottom navigation with a sliding rounded indicator.
Item {
    id: nav
    property int currentIndex: 0
    property var items: [
        { label: qsTr("Pictures"), icon: "pictures" },
        { label: qsTr("Videos"), icon: "video" },
        { label: qsTr("Albums"), icon: "albums" },
        { label: qsTr("Collections"), icon: "collections" },
        { label: qsTr("Folders"), icon: "folder" }
    ]
    signal selected(int index)

    property real maxWidth: 100000      // narrow windows: the items shrink to fit
    readonly property real itemWidth: Math.max(64, Math.min(100, (maxWidth - 12) / items.length))
    implicitWidth: items.length * itemWidth + 12
    implicitHeight: Theme.navHeight

    MultiEffect {
        source: pill
        anchors.fill: pill
        shadowEnabled: true
        shadowColor: Theme.shadow
        shadowBlur: 1.0
        shadowVerticalOffset: 4
        autoPaddingEnabled: true
    }
    Rectangle {
        id: pill
        anchors.fill: parent
        radius: height / 2
        color: Theme.navBg

        Rectangle {
            id: indicator
            y: 6
            height: parent.height - 12
            width: nav.itemWidth
            radius: height / 2
            color: Theme.accentSoft
            x: 6 + nav.currentIndex * nav.itemWidth
            Behavior on x { NumberAnimation { duration: Theme.durSlow; easing.type: Theme.easing } }
        }
        Row {
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
                model: nav.items
                delegate: Item {
                    required property var modelData
                    required property int index
                    width: nav.itemWidth
                    height: nav.height - 12
                    readonly property bool active: index === nav.currentIndex
                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: modelData.icon
                            size: 21
                            color: active ? Theme.accent : Theme.textSecondary
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.label
                            font.pixelSize: Theme.fontTiny + 1
                            font.weight: active ? Font.Bold : Font.Medium
                            color: active ? Theme.accent : Theme.textSecondary
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: nav.selected(index)
                    }
                }
            }
        }
    }
}
