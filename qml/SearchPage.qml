import QtQuick
import QtQuick.Controls
import "."
import "components"

// Search by file name, folder or date ("2025", "October", "Oct 2024", "Screenshots").
PhotoGrid {
    id: page
    photoModel: searchPhotos
    title: qsTr("Search")
    showBack: true
    bigHeader: false
    showSearchButton: false
    property string query: ""

    onQueryChanged: debounce.restart()
    Timer {
        id: debounce
        interval: 250
        onTriggered: {
            var q = page.query.trim()
            searchPhotos.setFilter(q === "" ? "none" : "search", q)
        }
    }

    barMiddle: Component {
        Rectangle {
            height: 42
            radius: 21
            color: Theme.surfaceHigh
            Icon {
                id: searchIcon
                x: Theme.s3
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                size: 18
                color: Theme.textSecondary
            }
            TextField {
                id: field
                anchors.left: searchIcon.right
                anchors.right: countLabel.left
                anchors.verticalCenter: parent.verticalCenter
                text: page.query
                placeholderText: qsTr("Search name, folder or date")
                placeholderTextColor: Theme.textSecondary
                color: Theme.text
                font.pixelSize: Theme.fontBody
                selectByMouse: true
                background: null
                onTextChanged: page.query = text
                Component.onCompleted: forceActiveFocus()
                Keys.onEscapePressed: (ev) => {
                    if (text !== "") { text = ""; ev.accepted = true } else ev.accepted = false
                }
            }
            Text {
                id: countLabel
                anchors.right: parent.right
                anchors.rightMargin: Theme.s4
                anchors.verticalCenter: parent.verticalCenter
                visible: page.query.trim() !== ""
                text: searchPhotos.loading ? "…" : searchPhotos.itemCount.toLocaleString(Qt.locale(), "f", 0)
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSmall
            }
        }
    }

    emptyState: Component {
        Column {
            spacing: Theme.s4
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: page.query.trim() === "" ? qsTr("Try searching for") : qsTr("No results for “%1”").arg(page.query.trim())
                color: Theme.textSecondary
                font.pixelSize: Theme.fontBody
            }
            Flow {
                width: parent.width
                spacing: Theme.s2
                visible: page.query.trim() === ""
                Repeater {
                    model: [new Date().getFullYear().toString(),
                            Qt.locale().monthName(new Date().getMonth(), Locale.LongFormat),
                            "Screenshot", "Camera", "WhatsApp"]
                    delegate: PillButton {
                        required property string modelData
                        compact: true
                        kind: "tonal"
                        text: modelData
                        onClicked: page.query = modelData
                    }
                }
            }
        }
    }
}
