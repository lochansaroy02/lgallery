import QtQuick
import QtQuick.Controls
import ".."

// The application menu inside the window (⋮ button): File ▸, Edit ▸, View ▸, ...
// Same MenuSpec tree as the global menu, so both always offer the same actions.
StyledMenu {
    id: root
    property var specs: []

    Component { id: menuComp; StyledMenu { } }
    Component { id: itemComp; AppMenuItem { } }
    Component {
        id: separatorComp
        MenuSeparator {
            height: visible ? implicitHeight : 0
            contentItem: Rectangle { implicitHeight: 1; implicitWidth: 260; color: Theme.divider }
        }
    }

    function build() {
        for (const spec of specs) {
            if (spec.inPopup === false) continue
            const sub = menuComp.createObject(root, { title: spec.text.replace("&", "") })
            fill(sub, spec)
            root.addMenu(sub)
        }
    }

    function fill(menu, spec) {
        populate(menu, spec)
        if (spec.model !== null || spec.submenu)
            spec.modelChanged.connect(function() { clear(menu); populate(menu, spec) })
    }

    function clear(menu) {
        while (menu.count > 0) {
            const item = menu.takeItem(0)
            if (item) item.destroy()
        }
    }

    function populate(menu, spec) {
        if (spec.dynamicFirst) addModel(menu, spec)
        for (const child of spec.items) addEntry(menu, child)
        if (!spec.dynamicFirst) addModel(menu, spec)
    }

    function addModel(menu, spec) {
        if (!spec.model) return
        for (const entry of spec.model) {
            const item = itemComp.createObject(menu.contentItem, {
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
        if (child.inPopup === false) return
        if (child.separator) {
            menu.addItem(separatorComp.createObject(menu.contentItem, { visible: Qt.binding(() => child.visible) }))
            return
        }
        if (child.isMenu) {
            const sub = menuComp.createObject(menu, {
                title: Qt.binding(() => child.text),
                enabled: Qt.binding(() => child.enabled)
            })
            fill(sub, child)
            menu.addMenu(sub)
            return
        }
        const item = itemComp.createObject(menu.contentItem, {
            text: Qt.binding(() => child.text),
            shortcutText: child.shortcut,
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
