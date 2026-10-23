import QtQuick
import QtQuick.Controls
import "."
import "components"

// One UI style photo editor: Transform (crop, rotate, flip, straighten),
// Filters and Adjust, with undo/redo, compare, Save, Save as copy and Revert.
Item {
    id: page
    visible: false
    focus: visible

    property string tab: "transform"
    property string adjustKey: "brightness"
    property bool comparing: false
    property bool overlayReady: false
    readonly property var win: ApplicationWindow.window
    readonly property color panelColor: "#0E0E10"
    readonly property var p: editor.params
    signal finished(string savedPath)

    function open(info) {
        if (!info || !info.path) return
        if (info.available === false) {
            win.showToast(qsTr("The drive with this picture is not available"))
            return
        }
        tab = "transform"
        adjustKey = "brightness"
        comparing = false
        overlayReady = false
        editor.open(info.path)
        editor.setCropMode(true)
        visible = true
        forceActiveFocus()
    }
    function close() {
        visible = false
        editor.close()
    }
    function requestClose() {
        if (editor.saving) return
        if (editor.dirty)
            win.confirm(qsTr("Discard changes?"), qsTr("Your edits to this picture will be lost."),
                        qsTr("Discard"), close)
        else
            close()
    }
    function save() { if (editor.dirty && !editor.saving) editor.save() }
    function saveCopy() { if (editor.dirty && !editor.saving) editor.saveCopy() }
    function revert() {
        var path = editor.path
        win.confirm(qsTr("Revert to original?"),
                    qsTr("All edits you saved to this picture are removed and the original file is restored."),
                    qsTr("Revert"),
                    function() { editor.revertOriginal(path); page.close() })
    }

    onTabChanged: {
        overlayReady = false
        editor.setCropMode(tab === "transform")
    }

    Connections {
        target: editor
        function onSaved(path, isCopy) {
            page.close()
            page.finished(path)
        }
        function onPreviewChanged() { page.overlayReady = editor.cropMode }
        function onStateChanged() {
            if (page.visible && editor.error !== "" && !editor.loading) page.close()
        }
    }

    Rectangle { anchors.fill: parent; color: "black" }

    // ---- top bar -----------------------------------------------------------------------
    Item {
        id: topBar
        width: parent.width
        height: 64
        Row {
            x: Theme.s2
            anchors.verticalCenter: parent.verticalCenter
            IconButton { icon: "close"; color: "white"; onDark: true; tip: qsTr("Cancel (Esc)"); onClicked: page.requestClose() }
            IconButton { icon: "undo"; color: "white"; onDark: true; enabled: editor.canUndo; tip: qsTr("Undo (Ctrl+Z)"); onClicked: editor.undo() }
            IconButton { icon: "redo"; color: "white"; onDark: true; enabled: editor.canRedo; tip: qsTr("Redo (Ctrl+Shift+Z)"); onClicked: editor.redo() }
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: Theme.s4
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.s2
            PillButton {
                compact: true
                kind: "text"
                text: qsTr("Revert")
                visible: editor.hasBackup && !editor.dirty
                onClicked: page.revert()
            }
            PillButton {
                compact: true
                kind: "text"
                text: qsTr("Reset")
                visible: editor.dirty
                onClicked: editor.resetAll()
            }
            PillButton {
                compact: true
                kind: "tonal"
                text: qsTr("Save as copy")
                enabled: editor.dirty && !editor.saving
                onClicked: page.saveCopy()
            }
            PillButton {
                compact: true
                text: qsTr("Save")
                enabled: editor.dirty && !editor.saving
                onClicked: page.save()
            }
        }
    }

    // ---- preview -----------------------------------------------------------------------------
    Item {
        id: stage
        anchors.top: topBar.bottom
        anchors.bottom: panel.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.s6

        Image {
            id: preview
            anchors.fill: parent
            fillMode: Image.PreserveAspectFit
            source: editor.previewUrl
            cache: false
            smooth: true
            mipmap: true
            visible: !page.comparing
        }
        Image {
            anchors.fill: parent
            fillMode: Image.PreserveAspectFit
            source: page.comparing ? editor.originalUrl : ""
            cache: false
            smooth: true
            visible: page.comparing
        }
        CropOverlay {
            visible: page.tab === "transform" && page.overlayReady && !page.comparing
                     && preview.status === Image.Ready && !editor.loading
            x: (stage.width - preview.paintedWidth) / 2
            y: (stage.height - preview.paintedHeight) / 2
            width: preview.paintedWidth
            height: preview.paintedHeight
            crop: page.p.crop
            aspect: editor.aspectRatio
            onCommitted: (x, y, w, h) => editor.setCrop(x, y, w, h)
        }
        BusyIndicator {
            anchors.centerIn: parent
            running: editor.loading
            visible: running
        }
    }

    // hold to compare with the original
    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: Theme.s4
        anchors.bottom: panel.top
        anchors.bottomMargin: Theme.s3
        width: 44
        height: 44
        radius: 22
        color: compareArea.pressed ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.1)
        visible: editor.dirty
        Icon { anchors.centerIn: parent; name: "compare"; color: "white"; size: 20 }
        MouseArea {
            id: compareArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onPressed: page.comparing = true
            onReleased: page.comparing = false
            onCanceled: page.comparing = false
        }
        ToolTip.visible: compareArea.containsMouse
        ToolTip.text: qsTr("Hold to compare with the original")
    }

    // ---- tools ----------------------------------------------------------------------------------
    Rectangle {
        id: panel
        anchors.bottom: parent.bottom
        width: parent.width
        height: 262
        color: page.panelColor

        Loader {
            id: tool
            anchors.top: parent.top
            anchors.topMargin: Theme.s3
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width - 2 * Theme.s5, 760)
            height: 180
            sourceComponent: page.tab === "transform" ? transformTool
                           : page.tab === "filters" ? filtersTool : adjustTool
        }

        Row {
            id: tabs
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.s4
            spacing: Theme.s2
            Repeater {
                model: [
                    { key: "transform", label: qsTr("Transform"), icon: "crop" },
                    { key: "filters", label: qsTr("Filters"), icon: "filters" },
                    { key: "adjust", label: qsTr("Adjust"), icon: "adjust" }
                ]
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool active: page.tab === modelData.key
                    width: tabRow.implicitWidth + 32
                    height: 40
                    radius: 20
                    color: active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25) : (tabMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                    Row {
                        id: tabRow
                        anchors.centerIn: parent
                        spacing: 6
                        Icon { name: modelData.icon; size: 17; color: active ? Theme.accent : "#C7C7CC"; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: modelData.label
                            color: active ? Theme.accent : "#C7C7CC"
                            font.pixelSize: Theme.fontSmall + 1
                            font.weight: active ? Font.Bold : Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        id: tabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.tab = modelData.key
                    }
                }
            }
        }
    }

    component Chip: Rectangle {
        id: chip
        property string label
        property bool selected: false
        signal clicked()
        width: chipText.implicitWidth + 28
        height: 32
        radius: 16
        color: selected ? Theme.accent : (chipMouse.containsMouse ? "#2C2C2E" : "#1F1F22")
        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            color: chip.selected ? "white" : "#E5E5EA"
            font.pixelSize: Theme.fontSmall
            font.weight: chip.selected ? Font.DemiBold : Font.Normal
        }
        MouseArea { id: chipMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.clicked() }
    }

    component ToolAction: Column {
        id: action
        property string icon
        property string label
        signal clicked()
        spacing: 4
        width: 84
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 48
            height: 48
            radius: 24
            color: actMouse.pressed ? "#3A3A3C" : (actMouse.containsMouse ? "#2C2C2E" : "#1F1F22")
            Icon { anchors.centerIn: parent; name: action.icon; color: "white"; size: 21 }
            MouseArea { id: actMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: action.clicked() }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: action.label
            color: "#C7C7CC"
            font.pixelSize: Theme.fontTiny + 1
        }
    }

    Component {
        id: transformTool
        Column {
            spacing: Theme.s3
            Item {
                width: parent.width
                height: 52
                Row {
                    id: straightenLabel
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    spacing: 6
                    Icon { name: "straighten"; color: "#C7C7CC"; size: 18 }
                    Text { text: qsTr("Straighten"); color: "#C7C7CC"; font.pixelSize: Theme.fontSmall }
                }
                EditSlider {
                    anchors.left: straightenLabel.right
                    anchors.leftMargin: Theme.s3
                    anchors.right: parent.right
                    height: parent.height
                    from: -45
                    to: 45
                    value: page.p.straighten
                    valueText: value.toFixed(1) + "°"
                    onMoved: (v) => editor.setValue("straighten", v)
                    onReleased: editor.commit()
                    onReset: editor.resetValue("straighten")
                }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.s2
                Repeater {
                    model: editor.aspects
                    delegate: Chip {
                        required property string modelData
                        label: modelData === "free" ? qsTr("Free") : modelData === "original" ? qsTr("Original") : modelData
                        selected: page.p.aspect === modelData
                        onClicked: editor.setAspect(modelData)
                    }
                }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.s2
                ToolAction { icon: "rotateLeft"; label: qsTr("Rotate"); onClicked: editor.rotateLeft() }
                ToolAction { icon: "flipH"; label: qsTr("Flip"); onClicked: editor.flipHorizontal() }
                ToolAction { icon: "flipV"; label: qsTr("Flip vertical"); onClicked: editor.flipVertical() }
            }
        }
    }

    Component {
        id: filtersTool
        Column {
            spacing: Theme.s1
            EditSlider {
                width: parent.width
                height: 50
                opacity: page.p.filter !== "none" ? 1 : 0
                enabled: page.p.filter !== "none"
                from: 0
                to: 100
                value: page.p.filterStrength * 100
                onMoved: (v) => editor.setValue("filterStrength", v / 100)
                onReleased: editor.commit()
                onReset: { editor.setValue("filterStrength", 1); editor.commit() }
            }
            ListView {
                id: filterList
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width, contentWidth)
                height: 96
                orientation: ListView.Horizontal
                spacing: Theme.s3
                clip: true
                model: editor.filters
                boundsBehavior: Flickable.StopAtBounds
                delegate: Column {
                    required property var modelData
                    readonly property bool selected: page.p.filter === modelData.name
                    spacing: 6
                    width: 68
                    Item {
                        width: 68
                        height: 68
                        RoundedImage {
                            anchors.fill: parent
                            radius: 16
                            maskColor: page.panelColor
                            source: editor.filterRevision > 0
                                    ? "image://edit/filter/" + modelData.name + "/" + editor.filterRevision : ""
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: 16
                            color: "transparent"
                            border.width: parent.parent.selected ? 3 : 0
                            border.color: Theme.accent
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: editor.setFilter(modelData.name)
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.label
                        color: parent.selected ? Theme.accent : "#C7C7CC"
                        font.pixelSize: Theme.fontTiny + 1
                        font.weight: parent.selected ? Font.Bold : Font.Normal
                    }
                }
            }
        }
    }

    Component {
        id: adjustTool
        Column {
            spacing: Theme.s1
            EditSlider {
                width: parent.width
                height: 50
                from: -100
                to: 100
                value: page.p[page.adjustKey] * 100
                onMoved: (v) => editor.setValue(page.adjustKey, v / 100)
                onReleased: editor.commit()
                onReset: editor.resetValue(page.adjustKey)
            }
            ListView {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width, contentWidth)
                height: 96
                orientation: ListView.Horizontal
                spacing: Theme.s1
                clip: true
                model: editor.adjustments
                boundsBehavior: Flickable.StopAtBounds
                delegate: Column {
                    required property var modelData
                    readonly property bool selected: page.adjustKey === modelData.key
                    readonly property bool changed: Math.abs(page.p[modelData.key]) > 0.004
                    spacing: 6
                    width: 76
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 52
                        height: 52
                        radius: 26
                        color: parent.selected ? Theme.accent : "#1F1F22"
                        Icon { anchors.centerIn: parent; name: modelData.icon; color: "white"; size: 21 }
                        Rectangle {
                            visible: parent.parent.changed && !parent.parent.selected
                            anchors.right: parent.right
                            anchors.top: parent.top
                            width: 10
                            height: 10
                            radius: 5
                            color: Theme.accent
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.adjustKey = modelData.key
                            onDoubleClicked: editor.resetValue(modelData.key)
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.label
                        color: parent.selected ? Theme.accent : "#C7C7CC"
                        font.pixelSize: Theme.fontTiny + 1
                        font.weight: parent.selected ? Font.Bold : Font.Normal
                    }
                }
            }
        }
    }

    // ---- saving overlay ---------------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.6)
        visible: editor.saving
        MouseArea { anchors.fill: parent; hoverEnabled: true }
        Column {
            anchors.centerIn: parent
            spacing: Theme.s3
            BusyIndicator { anchors.horizontalCenter: parent.horizontalCenter; running: editor.saving }
            Text { text: qsTr("Saving…"); color: "white"; font.pixelSize: Theme.fontBody }
        }
    }

    Keys.onPressed: (ev) => {
        var ctrl = ev.modifiers & Qt.ControlModifier
        var shift = ev.modifiers & Qt.ShiftModifier
        if (ctrl && ev.key === Qt.Key_Z && !shift) editor.undo()
        else if (ctrl && (ev.key === Qt.Key_Y || (ev.key === Qt.Key_Z && shift))) editor.redo()
        else if (ctrl && ev.key === Qt.Key_S && shift) page.saveCopy()
        else if (ctrl && ev.key === Qt.Key_S) page.save()
        else if (ev.key === Qt.Key_Backslash && !ev.isAutoRepeat) page.comparing = true
        else return
        ev.accepted = true
    }
    Keys.onReleased: (ev) => {
        if (ev.key === Qt.Key_Backslash && !ev.isAutoRepeat) { page.comparing = false; ev.accepted = true }
    }
}
