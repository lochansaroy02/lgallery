import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtCore
import "."
import "components"

ApplicationWindow {
    id: root
    width: 1200
    height: 820
    minimumWidth: 440
    minimumHeight: 520
    visible: true
    title: qsTr("Gallery")
    color: Theme.bg
    font.family: Theme.fontFamily

    Binding {
        target: Theme
        property: "dark"
        value: prefs.theme === "dark" || (prefs.theme === "system" && gallery.systemDark)
    }

    readonly property real navInset: Theme.navHeight + Theme.s5 * 2
    readonly property var currentGrid: stack.currentItem && stack.currentItem.grid ? stack.currentItem.grid : null
    readonly property bool dialogOpen: confirmDialog.opened || openWithPopup.opened
    readonly property bool editing: editorPage.visible

    // ---- API used by the views (via ApplicationWindow.window) -----------------------
    function openViewer(grid, index) { viewer.open(grid, index) }
    function openEditor(info) { editorPage.open(info) }
    function openWith(paths) { if (paths.length) openWithPopup.show(paths) }
    function addFolder() { folderDialog.open() }
    function showToast(message) { toast.show(message) }
    function confirm(title, message, action, callback) {
        confirmDialog.ask(title, message, action, callback, true)
    }
    function confirmDelete(paths, done) {
        if (!paths.length) return
        confirmDialog.ask(
            paths.length === 1 ? qsTr("Move this picture to the trash?")
                               : qsTr("Move %1 pictures to the trash?").arg(paths.length),
            qsTr("You can restore them from the Trash in Dolphin."),
            qsTr("Move to trash"),
            function() { gallery.trash(paths); if (done) done() }, true)
    }
    function openAlbum(kind, key, title) {
        albumPhotos.setFilter(kind, key)
        stack.push(albumPage, { title: title })
    }
    function openSearch() {
        if (!(stack.currentItem && stack.currentItem.isSearch)) stack.push(searchPage)
    }
    function openSettings() {
        if (!(stack.currentItem && stack.currentItem.isSettings)) stack.push(settingsPage)
    }
    function goBack() {
        if (editorPage.visible) editorPage.requestClose()
        else if (viewer.visible) viewer.close()
        else if (currentGrid && currentGrid.selectMode) currentGrid.exitSelection()
        else if (stack.depth > 1) stack.pop()
    }

    StackView {
        id: stack
        anchors.fill: parent
        initialItem: tabsPage

        pushEnter: Transition {
            NumberAnimation { property: "x"; from: stack.width * 0.08; to: 0; duration: Theme.durSlow; easing.type: Theme.easing }
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durNormal }
        }
        pushExit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.durNormal }
        }
        popEnter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durNormal }
        }
        popExit: Transition {
            NumberAnimation { property: "x"; from: 0; to: stack.width * 0.08; duration: Theme.durNormal; easing.type: Theme.easing }
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.durNormal }
        }
    }

    Component {
        id: tabsPage
        Item {
            id: tabs
            property int current: 0
            readonly property var grid: current === 0 ? pictures : null

            component Tab: Item {
                property int tabIndex
                anchors.fill: parent
                opacity: tabs.current === tabIndex ? 1 : 0
                visible: opacity > 0
                transform: Translate { y: tabs.current === tabIndex ? 0 : 16; Behavior on y { NumberAnimation { duration: Theme.durNormal; easing.type: Theme.easing } } }
                Behavior on opacity { NumberAnimation { duration: Theme.durNormal } }
            }

            Tab {
                tabIndex: 0
                PicturesView {
                    id: pictures
                    anchors.fill: parent
                    bottomInset: root.navInset
                    onSearchRequested: root.openSearch()
                    onSettingsRequested: root.openSettings()
                }
            }
            Tab {
                tabIndex: 1
                AlbumsView {
                    anchors.fill: parent
                    bottomInset: root.navInset
                    onOpenAlbum: (kind, key, title) => root.openAlbum(kind, key, title)
                    onSearchRequested: root.openSearch()
                    onSettingsRequested: root.openSettings()
                }
            }
            Tab {
                tabIndex: 2
                FoldersView {
                    anchors.fill: parent
                    bottomInset: root.navInset
                    onSettingsRequested: root.openSettings()
                }
            }

            PillNav {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: tabs.grid && tabs.grid.selectMode ? -height - 20 : Theme.s5
                Behavior on anchors.bottomMargin { NumberAnimation { duration: Theme.durNormal; easing.type: Theme.easing } }
                currentIndex: tabs.current
                onSelected: (i) => tabs.current = i
            }
        }
    }

    Component {
        id: albumPage
        PhotoGrid {
            id: albumGrid
            readonly property var grid: albumGrid
            photoModel: albumPhotos
            showBack: true
            onBackRequested: stack.pop()
            onSearchRequested: root.openSearch()
            StackView.onRemoved: albumPhotos.setFilter("none", "")
        }
    }

    Component {
        id: searchPage
        SearchPage {
            id: search
            readonly property var grid: search
            readonly property bool isSearch: true
            onBackRequested: stack.pop()
            StackView.onRemoved: searchPhotos.setFilter("none", "")
        }
    }

    Component {
        id: settingsPage
        SettingsView {
            readonly property bool isSettings: true
            onBackRequested: stack.pop()
        }
    }

    ViewerPage {
        id: viewer
        anchors.fill: parent
        z: 100
    }

    EditorPage {
        id: editorPage
        anchors.fill: parent
        z: 150
        onFinished: (path) => viewer.follow(path)
    }

    Toast {
        id: toast
        z: 200
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.navInset + Theme.s3
    }

    ConfirmDialog { id: confirmDialog }
    OpenWithPopup { id: openWithPopup }

    FolderDialog {
        id: folderDialog
        title: qsTr("Choose a folder to show in the gallery")
        currentFolder: StandardPaths.writableLocation(StandardPaths.PicturesLocation)
        onAccepted: gallery.addFolder(selectedFolder.toString())
    }

    Connections {
        target: gallery
        function onToast(message) { toast.show(message) }
    }

    // ---- keyboard ---------------------------------------------------------------------
    Shortcut {
        sequence: "Esc"
        enabled: !root.dialogOpen
        onActivated: root.goBack()
    }
    Shortcut {
        sequences: [StandardKey.Back]
        enabled: !root.dialogOpen && !viewer.visible
        onActivated: root.goBack()
    }
    Shortcut {
        sequences: [StandardKey.Find]
        enabled: !root.editing && !viewer.visible && !root.dialogOpen
        onActivated: root.openSearch()
    }
    Shortcut {
        sequence: "F5"
        enabled: !root.editing
        onActivated: gallery.rescan()
    }
    Shortcut {
        sequence: "Ctrl+O"
        enabled: !root.editing && !viewer.visible
        onActivated: root.addFolder()
    }
    Shortcut {
        sequences: [StandardKey.Preferences]
        enabled: !viewer.visible && !root.editing
        onActivated: root.openSettings()
    }
    Shortcut {
        sequence: "Ctrl+,"
        enabled: !viewer.visible && !root.editing
        onActivated: root.openSettings()
    }
    Shortcut {
        sequences: [StandardKey.SelectAll]
        enabled: !root.editing && !viewer.visible && root.currentGrid !== null && !root.dialogOpen
        onActivated: { root.currentGrid.selectMode = true; root.currentGrid.photoModel.selectAll() }
    }
    Shortcut {
        sequences: [StandardKey.Delete]
        enabled: !root.dialogOpen && !root.editing
        onActivated: {
            if (viewer.visible) viewer.deleteCurrent()
            else if (root.currentGrid && root.currentGrid.selectMode)
                root.confirmDelete(root.currentGrid.photoModel.selectedPaths(),
                                   function() { root.currentGrid.exitSelection() })
        }
    }
    Shortcut {
        sequences: [StandardKey.ZoomIn, "Ctrl+="]
        enabled: !root.editing && !viewer.visible && root.currentGrid !== null
        onActivated: root.currentGrid.changeColumns(-1)
    }
    Shortcut {
        sequences: [StandardKey.ZoomOut]
        enabled: !root.editing && !viewer.visible && root.currentGrid !== null
        onActivated: root.currentGrid.changeColumns(1)
    }
}
