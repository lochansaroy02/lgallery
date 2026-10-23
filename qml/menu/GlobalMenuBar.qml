import QtQuick
import Qt.labs.platform as Platform

// The KDE global menu (and macOS menu bar). Qt hands this native menu bar to the
// platform theme; on Plasma, KDE's Qt integration exports it to the Global Menu widget.
Platform.MenuBar {
    id: bar
    property var specs: []
    // native macOS menus trigger shortcuts themselves; elsewhere they only display them
    readonly property bool showShortcuts: Qt.platform.os !== "osx"

    Component { id: menuComp; Platform.Menu { } }
    Component { id: itemComp; Platform.MenuItem { } }
    Component { id: separatorComp; Platform.MenuSeparator { } }

    function build() {
        for (const spec of specs) {
            const menu = menuComp.createObject(bar, { title: spec.text })
            fill(menu, spec)
            bar.addMenu(menu)
        }
    }

    function fill(menu, spec) {
        populate(menu, spec)
        if (spec.model !== null || spec.submenu)
            spec.modelChanged.connect(function() { menu.clear(); populate(menu, spec) })
    }

    function populate(menu, spec) {
        if (spec.dynamicFirst) addModel(menu, spec)
        for (const child of spec.items) addEntry(menu, child)
        if (!spec.dynamicFirst) addModel(menu, spec)
    }

    function addModel(menu, spec) {
        if (!spec.model) return
        for (const entry of spec.model) {
            const item = itemComp.createObject(menu, {
                text: entry.text,
                checkable: entry.checked !== undefined,
                checked: entry.checked === true,
                enabled: entry.enabled !== false
            })
            item.triggered.connect(function() { spec.picked(entry.value) })
            menu.addItem(item)
        }
    }

    function addEntry(menu, child) {
        if (child.separator) {
            menu.addItem(separatorComp.createObject(menu, { visible: Qt.binding(() => child.visible) }))
            return
        }
        if (child.isMenu) {
            const sub = menuComp.createObject(menu, {
                title: Qt.binding(() => child.text),
                enabled: Qt.binding(() => child.enabled),
                visible: Qt.binding(() => child.visible)
            })
            fill(sub, child)
            menu.addMenu(sub)
            return
        }
        const item = itemComp.createObject(menu, {
            text: Qt.binding(() => child.text),
            shortcut: showShortcuts ? child.shortcut : "",
            enabled: Qt.binding(() => child.enabled),
            visible: Qt.binding(() => child.visible),
            checkable: child.checkable,
            checked: Qt.binding(() => child.checked)
        })
        item.triggered.connect(function() {
            child.triggered()
            if (child.checkable) item.checked = Qt.binding(() => child.checked)
        })
        menu.addItem(item)
    }

    Component.onCompleted: build()
}
