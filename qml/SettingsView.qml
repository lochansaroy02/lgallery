import QtQuick
import QtQuick.Controls
import "."
import "components"

// Preferences: theme, scanning options, cache and data locations.
Item {
    id: page
    signal backRequested()
    readonly property real headerHeight: Math.max(150, Math.min(250, height * 0.3))
    readonly property real collapse: Math.max(0, Math.min(1, flick.contentY / (headerHeight * 0.7)))

    Component.onCompleted: {
        gallery.refreshCacheSize()
        editor.refreshOriginalsSize()
        gallery.refreshDefaultViewer()
    }

    component Group: Column {
        property string title
        default property alias content: inner.data
        width: parent.width
        spacing: Theme.s2
        Text {
            leftPadding: Theme.s4
            text: parent.title
            color: Theme.accent
            font.pixelSize: Theme.fontSmall + 1
            font.weight: Font.DemiBold
        }
        Rectangle {
            width: parent.width
            height: inner.implicitHeight + Theme.s2 * 2
            radius: Theme.radiusL
            color: Theme.surface
            Column { id: inner; y: Theme.s2; width: parent.width }
        }
    }

    component SettingRow: Item {
        property string title
        property string subtitle
        default property alias control: holder.data
        width: parent ? parent.width : 0
        height: Math.max(64, texts.implicitHeight + 24)
        Column {
            id: texts
            anchors.left: parent.left
            anchors.leftMargin: Theme.s5
            anchors.right: holder.left
            anchors.rightMargin: Theme.s3
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                width: parent.width
                text: title
                wrapMode: Text.Wrap
                color: Theme.text
                font.pixelSize: Theme.fontBody + 1
            }
            Text {
                width: parent.width
                visible: subtitle !== ""
                text: subtitle
                wrapMode: Text.WrapAnywhere
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSmall
            }
        }
        Item {
            id: holder
            anchors.right: parent.right
            anchors.rightMargin: Theme.s5
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width
            height: childrenRect.height
        }
    }

    CollapsingHeader {
        id: bar
        z: 2
        width: parent.width
        title: qsTr("Settings")
        progress: page.collapse
        showBack: true
        onBackClicked: page.backRequested()
    }

    Timer {
        id: rescanLater
        interval: 1200
        onTriggered: gallery.rescan()
    }

    Flickable {
        id: flick
        anchors.top: bar.bottom
        anchors.bottom: parent.bottom
        width: parent.width
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentHeight: col.height + Theme.s6 * 2
        ScrollBar.vertical: ScrollBar { }

        Column {
            id: col
            width: Math.min(flick.width - 2 * Theme.pageMargin, 760)
            x: (flick.width - width) / 2
            spacing: Theme.s5

            BigTitle {
                width: parent.width
                height: page.headerHeight
                title: qsTr("Settings")
                progress: page.collapse
            }

            Group {
                title: qsTr("Appearance")
                SettingRow {
                    title: qsTr("Theme")
                    subtitle: qsTr("System follows your KDE colour scheme")
                    Segmented {
                        width: 270
                        value: prefs.theme
                        options: [
                            { value: "system", label: qsTr("System") },
                            { value: "light", label: qsTr("Light") },
                            { value: "dark", label: qsTr("Dark") }
                        ]
                        onPicked: (v) => prefs.theme = v
                    }
                }
                SettingRow {
                    title: qsTr("Grid columns")
                    subtitle: qsTr("Also Ctrl + mouse wheel or Ctrl +/- in the grid")
                    Row {
                        spacing: Theme.s1
                        IconButton { icon: "minus"; enabled: prefs.columns > prefs.minColumns; onClicked: prefs.columns = prefs.columns - 1 }
                        Text {
                            width: 34
                            horizontalAlignment: Text.AlignHCenter
                            anchors.verticalCenter: parent.verticalCenter
                            text: prefs.columns
                            color: Theme.text
                            font.pixelSize: Theme.fontLarge
                            font.weight: Font.DemiBold
                        }
                        IconButton { icon: "plus"; enabled: prefs.columns < prefs.maxColumns; onClicked: prefs.columns = prefs.columns + 1 }
                    }
                }
            }

            Group {
                title: qsTr("Default app")
                SettingRow {
                    title: qsTr("Default image viewer")
                    subtitle: gallery.defaultViewer === "default"
                              ? qsTr("Pictures you open in Dolphin or any file manager open in Gallery")
                              : gallery.defaultViewer === "not-installed"
                              ? qsTr("Install the launcher first (packaging/install-user.sh or the Arch package)")
                              : gallery.defaultViewer === "partial"
                              ? qsTr("Gallery opens some picture types. Set it for all of them?")
                              : qsTr("Open pictures from Dolphin in Gallery. Their folders are not added to the library.")
                    PillButton {
                        compact: true
                        kind: gallery.defaultViewer === "default" ? "tonal" : "filled"
                        text: gallery.defaultViewer === "default" ? qsTr("Is default") : qsTr("Set as default")
                        enabled: gallery.defaultViewer !== "default" && gallery.defaultViewer !== "not-installed"
                                 && gallery.defaultViewer !== ""
                        onClicked: gallery.setAsDefaultViewer()
                    }
                }
            }

            Group {
                title: qsTr("Library")
                SettingRow {
                    title: qsTr("Minimum file size")
                    subtitle: qsTr("Skip icons and tiny images smaller than this (KB)")
                    Row {
                        spacing: Theme.s1
                        IconButton {
                            icon: "minus"
                            enabled: prefs.minSizeKb > 0
                            onClicked: { prefs.minSizeKb = Math.max(0, prefs.minSizeKb - 10); rescanLater.restart() }
                        }
                        Text {
                            width: 54
                            horizontalAlignment: Text.AlignHCenter
                            anchors.verticalCenter: parent.verticalCenter
                            text: prefs.minSizeKb + " KB"
                            color: Theme.text
                            font.pixelSize: Theme.fontBody
                            font.weight: Font.DemiBold
                        }
                        IconButton {
                            icon: "plus"
                            onClicked: { prefs.minSizeKb = prefs.minSizeKb + 10; rescanLater.restart() }
                        }
                    }
                }
                SettingRow {
                    title: qsTr("Album per sub-folder")
                    subtitle: qsTr("Off: one album per watched folder")
                    OneSwitch {
                        checked: prefs.albumsBySubfolder
                        onToggled: (c) => prefs.albumsBySubfolder = c
                    }
                }
                SettingRow {
                    title: qsTr("Live updates")
                    subtitle: gallery.liveUpdatesSupported
                              ? qsTr("Pick up new and deleted files automatically")
                              : qsTr("Install python-watchdog to enable")
                    OneSwitch {
                        enabled: gallery.liveUpdatesSupported
                        checked: prefs.liveUpdates && gallery.liveUpdatesSupported
                        onToggled: (c) => prefs.liveUpdates = c
                    }
                }
                SettingRow {
                    title: qsTr("Rescan folders")
                    subtitle: gallery.scanning ? qsTr("Scanning… %1 found").arg(gallery.scanFound) : qsTr("Only changed files are read again")
                    PillButton {
                        compact: true
                        kind: "tonal"
                        text: qsTr("Rescan")
                        enabled: !gallery.scanning && gallery.hasFolders
                        onClicked: gallery.rescan()
                    }
                }
            }

            Group {
                title: qsTr("Storage")
                SettingRow {
                    title: qsTr("Thumbnail cache")
                    subtitle: gallery.cacheSize === "" ? "…" : gallery.cacheSize
                    PillButton {
                        compact: true
                        kind: "tonal"
                        text: qsTr("Clear")
                        onClicked: gallery.clearThumbnailCache()
                    }
                }
                SettingRow {
                    title: qsTr("Saved originals")
                    subtitle: qsTr("Kept when you save an edit, so you can revert. %1")
                              .arg(editor.originalsSize === "" ? "…" : editor.originalsSize)
                    PillButton {
                        compact: true
                        kind: "tonal"
                        text: qsTr("Delete")
                        onClicked: ApplicationWindow.window.confirm(
                            qsTr("Delete saved originals?"),
                            qsTr("Edited pictures can no longer be reverted to their originals."),
                            qsTr("Delete"), function() { editor.clearOriginals() })
                    }
                }
            }

            Group {
                title: qsTr("About")
                SettingRow {
                    title: qsTr("HEIC / HEIF support")
                    subtitle: gallery.heifSupported ? qsTr("Enabled (pillow-heif)") : qsTr("Install python-pillow-heif to enable")
                }
                SettingRow { title: qsTr("Index"); subtitle: gallery.locations.index }
                SettingRow { title: qsTr("Settings file"); subtitle: gallery.locations.config }
                SettingRow { title: qsTr("Thumbnail cache"); subtitle: gallery.locations.cache }
                SettingRow { title: qsTr("Saved originals"); subtitle: gallery.locations.originals }
            }
        }
    }
}
