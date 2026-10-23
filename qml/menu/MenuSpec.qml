import QtQuick

// One entry of the application menu. Declared once in AppMenuModel.qml and turned
// into both the KDE global menu (GlobalMenuBar) and the in-app ⋮ menu (AppPopupMenu).
//   - plain item:  text + triggered()
//   - submenu:     child MenuSpecs and/or a dynamic `model` ([{text, value, checked, enabled}])
//   - separator:   separator: true
QtObject {
    property string text
    property string shortcut          // shown in menus; with bindKey it is also a real shortcut
    property bool bindKey: false
    property bool enabled: true
    property bool visible: true
    property bool checkable: false
    property bool checked: false
    property bool separator: false
    property bool submenu: false      // force a submenu even if it only has a dynamic model
    property bool dynamicFirst: false // list model entries before the static children
    property var model: null
    default property list<QtObject> items
    readonly property bool isMenu: submenu || items.length > 0

    signal triggered()
    signal picked(var value)
}
