import QtQuick
import QtQuick.Controls
import "."
import "components"

// All people found in the library (Collections > People > See all).
Item {
    id: page
    property bool showHidden: false
    signal backRequested()
    signal openPerson(int personId, string name)
    readonly property real collapse: Math.max(0, Math.min(1, (grid.contentY - grid.originY) / 140))
    readonly property var people: showHidden ? collections.people.concat(collections.hiddenPeople) : collections.people

    CollapsingHeader {
        id: bar
        z: 2
        width: parent.width
        title: qsTr("People")
        progress: page.collapse
        showBack: true
        onBackClicked: page.backRequested()
        IconButton {
            visible: collections.hiddenPeople.length > 0
            icon: page.showHidden ? "eye" : "eyeOff"
            tip: page.showHidden ? qsTr("Hide hidden people") : qsTr("Show hidden people")
            onClicked: page.showHidden = !page.showHidden
        }
    }
    GridView {
        id: grid
        anchors.top: bar.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.pageMargin
        anchors.rightMargin: Theme.pageMargin
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        cellWidth: width / Math.max(3, Math.floor(width / 150))
        cellHeight: 190
        model: page.people
        header: BigTitle {
            width: grid.width
            height: 180
            title: qsTr("People")
            subtitle: collections.people.length === 1 ? qsTr("1 person") : qsTr("%1 people").arg(collections.people.length)
            progress: page.collapse
        }
        delegate: Item {
            required property var modelData
            width: grid.cellWidth
            height: grid.cellHeight
            PersonAvatar {
                anchors.horizontalCenter: parent.horizontalCenter
                size: 112
                person: modelData
                onClicked: page.openPerson(modelData.id, modelData.name)
            }
        }
    }
}
