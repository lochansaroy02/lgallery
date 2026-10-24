import QtQuick
import QtQuick.Controls
import ".."

// The viewer's ⋮ menu: themed like the rest of the app, with icons, grouped actions,
// Set as ▸ (wallpaper / lock screen / both) and Print… for pictures.
StyledMenu {
    id: menu
    property var viewer: null
    readonly property var win: viewer ? viewer.win : null
    readonly property var info: viewer ? viewer.info : ({})
    readonly property bool isPicture: info.video !== true
    readonly property bool usable: info.available === true
    readonly property int setAsIndex: 4   // after Open Gallery, Play video, Details, divider

    // "Set as" only exists for pictures: added / removed each time the menu opens
    property StyledMenu setAsMenu: StyledMenu {
        title: qsTr("Set as")
        iconName: "wallpaper"
        enabled: menu.usable && gallery.wallpaperSupported
        AppMenuItem {
            text: qsTr("Wallpaper")
            iconName: "monitor"
            onTriggered: gallery.setAsWallpaper(menu.info.path, "wallpaper")
        }
        AppMenuItem {
            text: qsTr("Lock screen")
            iconName: "lock"
            onTriggered: gallery.setAsWallpaper(menu.info.path, "lockscreen")
        }
        AppMenuItem {
            text: qsTr("Wallpaper and lock screen")
            iconName: "layers"
            onTriggered: gallery.setAsWallpaper(menu.info.path, "both")
        }
    }
    property bool setAsShown: false
    onAboutToShow: {
        if (isPicture && !setAsShown) { insertMenu(setAsIndex, setAsMenu); setAsShown = true }
        else if (!isPicture && setAsShown) { removeMenu(setAsMenu); setAsShown = false }
    }

    AppMenuItem {
        text: qsTr("Open Gallery")
        iconName: "pictures"
        visible: menu.win !== null && menu.win.standalone
        onTriggered: menu.win.showLibrary()
    }
    AppMenuItem {
        text: qsTr("Play video")
        iconName: "play"
        shortcutText: "Enter"
        visible: !menu.isPicture
        onTriggered: menu.viewer.playCurrent()
    }
    AppMenuItem {
        text: qsTr("Details")
        iconName: "info"
        shortcutText: "I"
        onTriggered: menu.viewer.detailsOpen = true
    }
    MenuDivider { }
    AppMenuItem {
        text: qsTr("Print…")
        iconName: "print"
        shortcutText: "Ctrl+P"
        visible: menu.isPicture
        enabled: menu.usable && gallery.printingSupported
        onTriggered: menu.win.printPicture(menu.info)
    }
    MenuDivider { visible: menu.isPicture }
    AppMenuItem {
        text: qsTr("Open with…")
        iconName: "openWith"
        onTriggered: menu.win.openWith([menu.info.path])
    }
    AppMenuItem {
        text: qsTr("Open in default app")
        iconName: "monitor"
        onTriggered: gallery.openExternally(menu.info.path)
    }
    AppMenuItem {
        text: qsTr("Show in folder")
        iconName: "showFolder"
        onTriggered: gallery.showInFolder(menu.info.path)
    }
    MenuDivider { }
    AppMenuItem {
        text: menu.isPicture ? qsTr("Copy picture") : qsTr("Copy video")
        iconName: "copy"
        shortcutText: "Ctrl+C"
        onTriggered: gallery.shareFiles([menu.info.path])
    }
    AppMenuItem {
        text: qsTr("Copy path")
        iconName: "file"
        shortcutText: "Ctrl+Shift+C"
        onTriggered: gallery.copyPaths([menu.info.path])
    }
    MenuDivider { visible: menu.viewer !== null && menu.viewer.canRevert }
    AppMenuItem {
        text: qsTr("Revert to original")
        iconName: "undo"
        danger: true
        visible: menu.viewer !== null && menu.viewer.canRevert
        onTriggered: menu.win.confirm(
            qsTr("Revert to original?"),
            qsTr("All edits you saved to this picture are removed and the original file is restored."),
            qsTr("Revert"), function() { editor.revertOriginal(menu.info.path) })
    }
}
