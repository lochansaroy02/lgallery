import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Window
import QtCore
import "."
import "components"
import "menu"

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
    readonly property bool dialogOpen: confirmDialog.opened || openWithPopup.opened || shareMenu.opened
                                       || shortcutsDialog.opened || aboutDialog.opened || appPopup.opened
                                       || nameDialog.opened || mergeDialog.opened
    readonly property bool editing: editorPage.visible || storyPlayer.visible
    // started by "Open with Gallery": closing the viewer quits instead of showing the library
    property bool standalone: launchedWithFiles
    property string externalFocus: ""
    property var tabsItem: null
    readonly property int currentTab: tabsItem ? tabsItem.current : 0
    readonly property bool canGoBack: editorPage.visible || viewer.visible
                                      || (currentGrid !== null && currentGrid.selectMode) || stack.depth > 1

    // ---- API used by the views (via ApplicationWindow.window) -----------------------
    function openViewer(grid, index) { viewer.open(grid, index) }
    function openEditor(info) { editorPage.open(info) }
    function raiseWindow() {
        if (root.visibility === Window.Minimized) root.showNormal()
        root.raise()
        root.requestActivate()
    }
    function goTab(index) {
        if (editorPage.visible) return
        if (viewer.visible) viewer.close()
        if (stack.depth > 1) stack.pop(null)
        if (tabsItem) tabsItem.current = index
    }
    function toggleFullScreen() {
        if (root.visibility === Window.FullScreen) root.showNormal()
        else root.showFullScreen()
    }
    function openPictureDialog() { openPicture.open() }
    function showShortcuts() { shortcutsDialog.open() }
    function showAbout() { aboutDialog.open() }
    function openAppMenu(anchor) {
        appPopup.popup(anchor, anchor.width - appPopup.implicitWidth, anchor.height)
    }
    function showLibrary() {
        // "Open Gallery" from a picture that was opened from the file manager
        standalone = false
        viewer.close()
    }
    function openWith(paths) { if (paths.length) openWithPopup.show(paths) }
    function share(paths, anchor, done) { if (paths.length) shareMenu.openFor(paths, anchor, done) }
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
    function openPerson(personId, name) {
        if (stack.currentItem && stack.currentItem.personId !== undefined && stack.currentItem.personId >= 0)
            stack.pop()
        albumPhotos.setFilter("person", String(personId))
        stack.push(albumPage, { title: name || qsTr("Add a name"), personId: personId })
    }
    function openPlace(key, name) {
        albumPhotos.setFilter("place", key)
        stack.push(albumPage, { title: name })
    }
    function openPeople() { stack.push(peoplePage) }
    function openPlaces() { stack.push(placesPage) }
    function playStory(story) { storyPlayer.play(story) }
    // show a library picture in the viewer (from a story)
    function openLibraryPicture(path) {
        goTab(0)
        Qt.callLater(function() {
            var index = photos.indexOfPath(path)
            if (index >= 0 && root.currentGrid) {
                root.currentGrid.ensureVisible(index)
                viewer.open(root.currentGrid, index)
            } else {
                gallery.openFiles([path])
            }
        })
    }
    function openSearch() {
        if (!(stack.currentItem && stack.currentItem.isSearch)) stack.push(searchPage)
    }
    function openSettings() {
        if (!(stack.currentItem && stack.currentItem.isSettings)) stack.push(settingsPage)
    }
    function goBack() {
        if (storyPlayer.visible) storyPlayer.close()
        else if (editorPage.visible) editorPage.requestClose()
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
            Component.onCompleted: root.tabsItem = tabs

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
                CollectionsView {
                    anchors.fill: parent
                    bottomInset: root.navInset
                    onPlayStory: (story) => root.playStory(story)
                    onOpenPeople: root.openPeople()
                    onOpenPlaces: root.openPlaces()
                    onOpenPerson: (personId, name) => root.openPerson(personId, name)
                    onOpenPlace: (key, name) => root.openPlace(key, name)
                }
            }
            Tab {
                tabIndex: 3
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
            property int personId: -1
            readonly property bool personHidden: collections.hiddenPeople.some(p => p.id === personId)
            photoModel: albumPhotos
            showBack: true
            onBackRequested: stack.pop()
            onSearchRequested: root.openSearch()
            StackView.onRemoved: albumPhotos.setFilter("none", "")
            extraActions: personId < 0 ? [] : [
                { id: "name", icon: "edit", tip: qsTr("Name this person") },
                { id: "merge", icon: "merge", tip: qsTr("Same person as…") },
                personHidden ? { id: "unhide", icon: "eye", tip: qsTr("Show this person again") }
                             : { id: "hide", icon: "eyeOff", tip: qsTr("Hide this person") }
            ]
            onExtraAction: (id) => {
                const pid = albumGrid.personId
                if (id === "name") {
                    nameDialog.ask(collections.personName(pid), function(name) {
                        collections.renamePerson(pid, name)
                        albumGrid.title = name || qsTr("Add a name")
                    })
                } else if (id === "merge") {
                    mergeDialog.ask(pid, function(target) {
                        collections.mergePeople(pid, target)
                        stack.pop()
                        toast.show(qsTr("Pictures combined"))
                    })
                } else if (id === "hide") {
                    collections.setPersonHidden(pid, true)
                    stack.pop()
                    toast.show(qsTr("Person hidden. Show hidden people from the People page."))
                } else if (id === "unhide") {
                    collections.setPersonHidden(pid, false)
                }
            }
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
        id: peoplePage
        PeoplePage {
            onBackRequested: stack.pop()
            onOpenPerson: (personId, name) => root.openPerson(personId, name)
        }
    }
    Component {
        id: placesPage
        PlacesPage {
            onBackRequested: stack.pop()
            onOpenPlace: (key, name) => root.openPlace(key, name)
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

    StoryPlayer {
        id: storyPlayer
        anchors.fill: parent
        z: 120
        onOpenPicture: (path) => root.openLibraryPicture(path)
    }

    Toast {
        id: toast
        z: 200
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.navInset + Theme.s3
    }

    // ---- application menu: KDE global menu + the in-app ⋮ menu ----------------------------
    AppMenuModel {
        id: appMenu
        win: root
        viewer: viewer
        editorPage: editorPage
    }
    // only where a global menu is running (otherwise Qt has no native menu bar to fill)
    Loader {
        active: gallery.globalMenuAvailable
        sourceComponent: Component { GlobalMenuBar { specs: appMenu.menus; window: root } }
    }
    AppPopupMenu { id: appPopup; specs: appMenu.menus }
    ShortcutsDialog { id: shortcutsDialog }
    NameDialog { id: nameDialog }
    MergeDialog { id: mergeDialog }
    AboutDialog { id: aboutDialog }

    FileDialog {
        id: openPicture
        title: qsTr("Open pictures")
        fileMode: FileDialog.OpenFiles
        currentFolder: StandardPaths.writableLocation(StandardPaths.PicturesLocation)
        nameFilters: [qsTr("Pictures (*.jpg *.jpeg *.png *.webp *.gif *.bmp *.tif *.tiff *.heic *.heif)"),
                      qsTr("All files (*)")]
        onAccepted: gallery.openFiles(selectedFiles.map(u => u.toString()))
    }

    // keep the Share submenu ready for the current selection
    Connections {
        target: root.currentGrid ? root.currentGrid.photoModel : null
        function onSelectionChanged() {
            const model = root.currentGrid.photoModel
            if (model.selectionCount > 0) gallery.prepareShare(model.selectedPaths().slice(0, 20))
        }
    }

    Component.onCompleted: {
        appMenu.installShortcuts(root.contentItem)
        gallery.refreshDefaultViewer()
    }

    ConfirmDialog { id: confirmDialog }
    OpenWithPopup { id: openWithPopup }
    ShareMenu { id: shareMenu }

    FolderDialog {
        id: folderDialog
        title: qsTr("Choose a folder to show in the gallery")
        currentFolder: StandardPaths.writableLocation(StandardPaths.PicturesLocation)
        onAccepted: gallery.addFolder(selectedFolder.toString())
    }

    Connections {
        target: gallery
        function onToast(message) { toast.show(message) }
        function onActivateRequested() { root.raiseWindow() }
        function onExternalOpenRequested(path) {
            if (editorPage.visible) editorPage.close()
            if (viewer.visible && viewer.photoModel === externalPhotos) {
                viewer.follow(path)          // already browsing outside files: jump there
            } else {
                root.externalFocus = path
                viewer.showBlank()           // black screen until the folder is listed
            }
            root.raiseWindow()
        }
    }

    // a stand-in "grid" for pictures that are not in the library
    QtObject {
        id: externalGrid
        readonly property var photoModel: externalPhotos
        property bool selectMode: false
        function rectForItem(index) { return null }
        function ensureVisible(index) { }
    }
    Connections {
        target: externalPhotos
        function onViewReset() {
            if (root.externalFocus === "") return
            var idx = externalPhotos.indexOfPath(root.externalFocus)
            if (idx < 0) return
            root.externalFocus = ""
            viewer.open(externalGrid, idx)
        }
    }
    Connections {
        target: viewer
        function onVisibleChanged() {
            if (!viewer.visible && root.standalone) Qt.quit()
        }
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
