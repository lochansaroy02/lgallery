import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Effects
import ".."
import "../menu"

// One UI style print sheet: live page preview on the left, options on the right.
// Printers come from CUPS (Qt Print Support); "Save as PDF" is always offered.
Popup {
    id: dlg
    property var info: ({})
    property var printers: []
    property int printerIndex: 0
    property bool loading: false
    property string paper: "a4"
    property string orientation: "auto"     // auto | portrait | landscape
    property string scaling: "fit"          // fit | fill
    property bool borderless: false
    property bool gray: false
    property int copies: 1
    property string pdfPath: ""

    readonly property var printer: printers.length > printerIndex ? printers[printerIndex] : null
    readonly property bool toPdf: printer !== null && printer.pdf === true
    readonly property bool wide: width >= 640
    // paper sizes in mm (portrait)
    readonly property var paperMm: ({
        "a4": [210, 297], "letter": [215.9, 279.4], "a5": [148, 210], "a3": [297, 420],
        "legal": [215.9, 355.6], "10x15": [101.6, 152.4], "13x18": [127, 177.8]
    })
    readonly property bool landscape: orientation === "auto" ? (info.width > info.height) : orientation === "landscape"
    readonly property var pageMm: {
        var p = paperMm[paper] || paperMm["a4"]
        return landscape ? [p[1], p[0]] : p
    }

    function openFor(i) {
        info = i
        copies = 1
        pdfPath = gallery.defaultPdfPath(i.path)
        loading = true
        gallery.requestPrinters()
        open()
    }
    function paperLabel(v) {
        var list = gallery.paperSizes
        for (var k = 0; k < list.length; ++k) if (list[k].value === v) return list[k].label
        return v
    }
    function start() {
        if (!printer) return
        gallery.printImage(info.path, {
            printer: printer.id, printerName: printer.name, pdfPath: pdfPath, paper: paper,
            orientation: orientation, fill: scaling === "fill", borderless: borderless,
            gray: gray, copies: copies
        })
        close()
    }

    Connections {
        target: gallery
        function onPrintersLoaded(result) {
            dlg.printers = result.printers
            dlg.printerIndex = 0
            dlg.paper = result.paper || "a4"
            dlg.loading = false
        }
    }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(760, parent ? parent.width - 32 : 760)
    height: Math.min(implicitHeight, parent ? parent.height - 32 : 600)
    modal: true
    focus: true
    padding: Theme.s5
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    Overlay.modal: Rectangle { color: Theme.scrim }
    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durNormal }
        NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: Theme.durNormal; easing.type: Theme.easing }
    }
    exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: Theme.durFast } }
    background: Rectangle { radius: Theme.radiusXL; color: Theme.surface }

    // ---- small building blocks ------------------------------------------------------------------
    component FieldLabel: Text {
        color: Theme.textSecondary
        font.pixelSize: Theme.fontSmall
        font.weight: Font.DemiBold
    }
    component Dropdown: Rectangle {
        id: dd
        property string text
        property string icon: ""
        signal clicked()
        implicitHeight: 44
        radius: Theme.radiusS
        color: ddMouse.containsMouse ? Qt.darker(Theme.surfaceHigh, Theme.dark ? 0.85 : 1.04) : Theme.surfaceHigh
        Row {
            anchors.left: parent.left
            anchors.leftMargin: Theme.s3
            anchors.right: chevron.left
            anchors.rightMargin: Theme.s2
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.s2
            Icon { visible: dd.icon !== ""; name: dd.icon; size: 18; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - (dd.icon !== "" ? 26 : 0)
                text: dd.text
                elide: Text.ElideRight
                color: Theme.text
                font.pixelSize: Theme.fontBody
            }
        }
        Icon { id: chevron; anchors.right: parent.right; anchors.rightMargin: Theme.s3; anchors.verticalCenter: parent.verticalCenter; name: "chevronDown"; size: 18; color: Theme.textSecondary }
        MouseArea { id: ddMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: dd.clicked() }
    }

    contentItem: Flickable {
        implicitHeight: body.implicitHeight
        contentHeight: body.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: body
            width: parent.width
            spacing: Theme.s4

            Text {
                text: qsTr("Print")
                color: Theme.text
                font.pixelSize: Theme.fontTitle + 2
                font.weight: Font.Bold
            }

            Flow {
                width: parent.width
                spacing: Theme.s5

                // ---- page preview ----
                Rectangle {
                    id: previewBox
                    width: dlg.wide ? 300 : parent.width
                    height: dlg.wide ? 380 : 260
                    radius: Theme.radiusL
                    color: Theme.surfaceHigh

                    readonly property real scaleMm: Math.min((width - 48) / dlg.pageMm[0], (height - 48) / dlg.pageMm[1])
                    MultiEffect {
                        source: page
                        anchors.fill: page
                        shadowEnabled: true
                        shadowColor: Qt.rgba(0, 0, 0, 0.25)
                        shadowBlur: 0.6
                        shadowVerticalOffset: 3
                        autoPaddingEnabled: true
                    }
                    Rectangle {
                        id: page
                        anchors.centerIn: parent
                        width: dlg.pageMm[0] * previewBox.scaleMm
                        height: dlg.pageMm[1] * previewBox.scaleMm
                        color: "white"
                        Behavior on width { NumberAnimation { duration: Theme.durNormal; easing.type: Theme.easing } }
                        Behavior on height { NumberAnimation { duration: Theme.durNormal; easing.type: Theme.easing } }
                        Item {
                            anchors.fill: parent
                            anchors.margins: dlg.borderless ? 0 : 5 * previewBox.scaleMm
                            clip: true
                            Image {
                                id: previewImg
                                anchors.fill: parent
                                source: dlg.opened ? (dlg.info.thumb || "") : ""
                                fillMode: dlg.scaling === "fill" ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                                asynchronous: true
                                smooth: true
                                visible: !dlg.gray
                            }
                            MultiEffect {
                                anchors.fill: previewImg
                                source: previewImg
                                visible: dlg.gray
                                saturation: -1
                            }
                        }
                    }
                    Text {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 6
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: dlg.paperLabel(dlg.paper) + "  ·  " + (dlg.landscape ? qsTr("Landscape") : qsTr("Portrait"))
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontTiny + 1
                    }
                }

                // ---- options ----
                Column {
                    width: dlg.wide ? parent.width - previewBox.width - Theme.s5 : parent.width
                    spacing: Theme.s3

                    FieldLabel { text: qsTr("Printer") }
                    Dropdown {
                        id: printerField
                        width: parent.width
                        icon: dlg.toPdf ? "file" : "print"
                        text: dlg.loading ? qsTr("Looking for printers…") : dlg.printer ? dlg.printer.name : ""
                        onClicked: printerMenu.popup(printerField, 0, printerField.height + 4)
                        StyledMenu {
                            id: printerMenu
                            Instantiator {
                                model: dlg.printers
                                onObjectAdded: (i, obj) => printerMenu.insertItem(i, obj)
                                onObjectRemoved: (i, obj) => printerMenu.removeItem(obj)
                                delegate: AppMenuItem {
                                    required property var modelData
                                    required property int index
                                    text: modelData.name + (modelData.isDefault && !modelData.pdf ? qsTr("  (default)") : "")
                                    iconName: modelData.pdf ? "file" : "print"
                                    checkable: true
                                    checked: index === dlg.printerIndex
                                    onTriggered: dlg.printerIndex = index
                                }
                            }
                        }
                    }
                    Row {
                        width: parent.width
                        visible: dlg.toPdf
                        spacing: Theme.s2
                        Text {
                            width: parent.width - changeBtn.width - Theme.s2
                            anchors.verticalCenter: parent.verticalCenter
                            text: dlg.pdfPath
                            elide: Text.ElideMiddle
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSmall
                        }
                        PillButton {
                            id: changeBtn
                            kind: "text"
                            compact: true
                            text: qsTr("Change…")
                            onClicked: {
                                pdfDialog.currentFile = "file://" + dlg.pdfPath
                                pdfDialog.open()
                            }
                        }
                    }

                    FieldLabel { text: qsTr("Paper size") }
                    Dropdown {
                        id: paperField
                        width: parent.width
                        text: dlg.paperLabel(dlg.paper)
                        onClicked: paperMenu.popup(paperField, 0, paperField.height + 4)
                        StyledMenu {
                            id: paperMenu
                            Instantiator {
                                model: gallery.paperSizes
                                onObjectAdded: (i, obj) => paperMenu.insertItem(i, obj)
                                onObjectRemoved: (i, obj) => paperMenu.removeItem(obj)
                                delegate: AppMenuItem {
                                    required property var modelData
                                    text: modelData.label
                                    checkable: true
                                    checked: modelData.value === dlg.paper
                                    onTriggered: dlg.paper = modelData.value
                                }
                            }
                        }
                    }

                    FieldLabel { text: qsTr("Orientation") }
                    Segmented {
                        width: parent.width
                        value: dlg.orientation
                        options: [{ value: "auto", label: qsTr("Auto") }, { value: "portrait", label: qsTr("Portrait") },
                                  { value: "landscape", label: qsTr("Landscape") }]
                        onPicked: (v) => dlg.orientation = v
                    }
                    FieldLabel { text: qsTr("Picture") }
                    Segmented {
                        width: parent.width
                        value: dlg.scaling
                        options: [{ value: "fit", label: qsTr("Fit to page") }, { value: "fill", label: qsTr("Fill page") }]
                        onPicked: (v) => dlg.scaling = v
                    }
                    Segmented {
                        width: parent.width
                        value: dlg.gray ? "gray" : "color"
                        options: [{ value: "color", label: qsTr("Colour") }, { value: "gray", label: qsTr("Black & white") }]
                        onPicked: (v) => dlg.gray = v === "gray"
                    }

                    Item {
                        width: parent.width
                        height: 40
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Borderless")
                            color: Theme.text
                            font.pixelSize: Theme.fontBody
                        }
                        OneSwitch {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            checked: dlg.borderless
                            onToggled: (c) => dlg.borderless = c
                        }
                    }
                    Item {
                        width: parent.width
                        height: 40
                        visible: !dlg.toPdf
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Copies")
                            color: Theme.text
                            font.pixelSize: Theme.fontBody
                        }
                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.s2
                            IconButton {
                                icon: "minus"
                                width: 36; height: 36
                                iconSize: 18
                                enabled: dlg.copies > 1
                                onClicked: dlg.copies--
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 28
                                horizontalAlignment: Text.AlignHCenter
                                text: dlg.copies
                                color: Theme.text
                                font.pixelSize: Theme.fontLarge
                                font.weight: Font.DemiBold
                            }
                            IconButton {
                                icon: "plus"
                                width: 36; height: 36
                                iconSize: 18
                                enabled: dlg.copies < 99
                                onClicked: dlg.copies++
                            }
                        }
                    }
                }
            }

            Row {
                anchors.right: parent.right
                spacing: Theme.s2
                PillButton {
                    kind: "text"
                    text: qsTr("Cancel")
                    onClicked: dlg.close()
                }
                PillButton {
                    kind: "filled"
                    icon: dlg.toPdf ? "file" : "print"
                    enabled: !dlg.loading && dlg.printer !== null
                    text: dlg.toPdf ? qsTr("Save PDF") : qsTr("Print")
                    onClicked: dlg.start()
                }
            }
        }
    }

    FileDialog {
        id: pdfDialog
        title: qsTr("Save as PDF")
        fileMode: FileDialog.SaveFile
        defaultSuffix: "pdf"
        nameFilters: [qsTr("PDF files (*.pdf)")]
        onAccepted: {
            var url = selectedFile.toString()
            dlg.pdfPath = decodeURIComponent(url.replace(/^file:\/\//, ""))
        }
    }
}
