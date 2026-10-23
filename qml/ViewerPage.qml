import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "."
import "components"

// Full-screen viewer: swipe / arrow keys to navigate, wheel / double-click / pinch
// to zoom, drag to pan, Esc to close. Opens and closes with a shared-element
// transition from the grid thumbnail.
Item {
    id: viewer
    visible: false
    focus: visible

    property var grid: null
    readonly property var photoModel: grid ? grid.photoModel : null
    property int currentIndex: 0
    property var info: ({})
    property bool chrome: true
    property bool detailsOpen: false
    property bool closing: false
    readonly property bool isOpen: visible && !closing
    readonly property var win: ApplicationWindow.window
    property int keepId: -1
    property int keepIndex: 0
    property int revision: 0          // bumps when the model data changes (edits, favorites)
    property string followPath: ""    // after "Save as copy", jump to the new file
    property bool canRevert: false

    function refreshInfo() {
        info = photoModel && currentIndex >= 0 && currentIndex < photoModel.itemCount
               ? photoModel.itemAt(currentIndex) : ({})
        canRevert = info.path ? editor.hasOriginal(info.path) : false
    }
    function follow(path) { followPath = path }
    onCurrentIndexChanged: refreshInfo()

    function fitRect(w, h) {
        if (!(w > 0 && h > 0)) { w = width; h = height }
        var s = Math.min(width / w, height / h)
        return { x: (width - w * s) / 2, y: (height - h * s) / 2, width: w * s, height: h * s }
    }

    // black, empty viewer shown while a picture opened from the file manager loads
    function showBlank() {
        openAnim.stop()
        closeAnim.stop()
        closing = false
        proxy.visible = false
        pager.opacity = 0
        backdrop.opacity = 1
        visible = true
    }

    function open(g, index) {
        var wasBlank = visible && !closing && backdrop.opacity === 1 && pager.opacity === 0
        openAnim.stop()
        closeAnim.stop()
        closing = false
        grid = g
        currentIndex = index
        refreshInfo()
        chrome = true
        detailsOpen = false
        visible = true
        pager.positionViewAtIndex(index, ListView.Beginning)
        pager.currentIndex = index
        forceActiveFocus()
        if (wasBlank) {             // opened from the file manager: no zoom-in animation
            proxy.visible = false
            backdrop.opacity = 1
            pager.opacity = 1
            return
        }
        var r = g.rectForItem(index)
        var target = fitRect(info.width, info.height)
        proxy.source = info.thumb || ""
        if (r) {
            proxy.x = r.x; proxy.y = r.y; proxy.width = r.width; proxy.height = r.height
        } else {
            proxy.x = target.x + target.width * 0.05; proxy.y = target.y + target.height * 0.05
            proxy.width = target.width * 0.9; proxy.height = target.height * 0.9
        }
        proxy.fillMode = Image.PreserveAspectCrop
        toX.to = target.x; toY.to = target.y; toW.to = target.width; toH.to = target.height
        proxy.visible = true
        pager.opacity = 0
        backdrop.opacity = 0
        openAnim.start()
    }

    function close() {
        if (!visible || closing) return
        closing = true
        detailsOpen = false
        var page = pager.currentItem
        if (page) page.resetZoom()
        grid.ensureVisible(currentIndex)
        Qt.callLater(function() {
            var r = grid.rectForItem(currentIndex)
            var from = fitRect(info.width, info.height)
            proxy.source = info.thumb || ""
            proxy.fillMode = Image.PreserveAspectCrop
            proxy.x = from.x; proxy.y = from.y; proxy.width = from.width; proxy.height = from.height
            if (r) {
                backX.to = r.x; backY.to = r.y; backW.to = r.width; backH.to = r.height
            } else {
                backX.to = from.x + from.width * 0.1; backY.to = from.y + from.height * 0.1
                backW.to = from.width * 0.8; backH.to = from.height * 0.8
            }
            proxy.visible = true
            pager.opacity = 0
            closeAnim.start()
        })
    }

    function go(delta) {
        var n = currentIndex + delta
        if (photoModel && n >= 0 && n < photoModel.itemCount) pager.currentIndex = n
    }

    function deleteCurrent() {
        if (!info.path) return
        win.confirmDelete([info.path], null)
    }

    function toggleFavorite() {
        if (info.id === undefined || info.external) return
        gallery.setFavorite([info.id], !info.favorite)
    }

    Connections {
        target: editor
        function onReverted(path) { viewer.refreshInfo() }
        function onSaved(path, isCopy) { viewer.refreshInfo() }
    }

    // keep showing the same picture when the model is rebuilt (scan, delete, ...)
    Connections {
        target: viewer.photoModel
        enabled: viewer.visible
        function onViewAboutToReset() {
            viewer.keepId = viewer.info.id !== undefined ? viewer.info.id : -1
            viewer.keepIndex = viewer.currentIndex
        }
        function onViewReset() {
            var count = viewer.photoModel.itemCount
            viewer.revision++
            if (count === 0) { viewer.closing = false; viewer.visible = false; return }
            var idx = viewer.followPath !== "" ? viewer.photoModel.indexOfPath(viewer.followPath) : -1
            viewer.followPath = ""
            if (idx < 0) idx = viewer.photoModel.indexOfId(viewer.keepId)
            if (idx < 0) idx = Math.min(viewer.keepIndex, count - 1)
            pager.positionViewAtIndex(idx, ListView.Beginning)
            pager.currentIndex = idx
            viewer.currentIndex = idx
            viewer.refreshInfo()
        }
        function onDataChanged() { viewer.revision++; viewer.refreshInfo() }
    }

    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: "black"
    }

    ListView {
        id: pager
        anchors.fill: parent
        orientation: ListView.Horizontal
        snapMode: ListView.SnapOneItem
        highlightRangeMode: ListView.StrictlyEnforceRange
        highlightMoveDuration: Theme.durNormal
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: width * 2
        reuseItems: false
        model: viewer.visible && viewer.photoModel ? viewer.photoModel.itemCount : 0
        interactive: !(currentItem && currentItem.zoomed)
        onCurrentIndexChanged: if (currentIndex >= 0) viewer.currentIndex = currentIndex

        delegate: Item {
            id: page
            required property int index
            width: pager.width
            height: pager.height
            clip: true
            readonly property var item: viewer.revision >= 0 && viewer.photoModel ? viewer.photoModel.itemAt(index) : ({})
            readonly property bool isCurrent: ListView.isCurrentItem
            property real zoom: 1
            property real panX: 0
            property real panY: 0
            readonly property bool zoomed: zoom > 1.01
            readonly property real fitScale: item.width > 0 ? Math.min(width / item.width, height / item.height) : 1
            readonly property real paintedW: item.width > 0 ? item.width * fitScale : width
            readonly property real paintedH: item.height > 0 ? item.height * fitScale : height

            function clampPan() {
                var mx = Math.max(0, (paintedW * zoom - width) / 2)
                var my = Math.max(0, (paintedH * zoom - height) / 2)
                panX = Math.max(-mx, Math.min(mx, panX))
                panY = Math.max(-my, Math.min(my, panY))
            }
            function zoomAt(z, sx, sy) {
                z = Math.max(1, Math.min(8, z))
                var cx = width / 2, cy = height / 2
                var px = cx + (sx - cx - panX) / zoom
                var py = cy + (sy - cy - panY) / zoom
                panX = sx - cx - (px - cx) * z
                panY = sy - cy - (py - cy) * z
                zoom = z
                if (z <= 1.001) { panX = 0; panY = 0 }
                clampPan()
            }
            function resetZoom() { zoom = 1; panX = 0; panY = 0 }
            onIsCurrentChanged: if (!isCurrent) resetZoom()

            Behavior on zoom { enabled: zoomAnim.running; NumberAnimation { duration: Theme.durNormal; easing.type: Theme.easing } }
            Timer { id: zoomAnim; interval: Theme.durNormal + 20 }
            function animatedZoomAt(z, sx, sy) { zoomAnim.restart(); zoomAt(z, sx, sy) }

            Item {
                id: content
                width: page.width
                height: page.height
                transform: [
                    Scale { origin.x: content.width / 2; origin.y: content.height / 2; xScale: page.zoom; yScale: page.zoom },
                    Translate { x: page.panX; y: page.panY }
                ]
                Image {
                    id: low
                    anchors.fill: parent
                    source: page.item.thumb || ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    visible: full.status !== Image.Ready && !page.item.animated
                }
                Image {
                    id: full
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                    smooth: true
                    mipmap: true
                    visible: !page.item.animated
                    source: !page.item.animated && Math.abs(page.index - pager.currentIndex) <= 1 ? (page.item.full || "") : ""
                    sourceSize: Qt.size(Math.min(3840, Math.round(page.width * Screen.devicePixelRatio)),
                                        Math.min(3840, Math.round(page.height * Screen.devicePixelRatio)))
                }
                // sharper decode once zoomed in
                Image {
                    id: hires
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                    smooth: true
                    visible: status === Image.Ready && page.zoom > 1.4
                    source: page.isCurrent && page.zoom > 1.4 && !page.item.animated ? (page.item.full || "") : ""
                    sourceSize: Qt.size(Math.min(8192, Math.round(page.width * Screen.devicePixelRatio * 3)),
                                        Math.min(8192, Math.round(page.height * Screen.devicePixelRatio * 3)))
                }
                AnimatedImage {
                    anchors.fill: parent
                    visible: page.item.animated === true
                    source: page.item.animated ? page.item.url : ""
                    fillMode: Image.PreserveAspectFit
                    playing: page.isCurrent && viewer.visible
                    asynchronous: true
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: Theme.s3
                visible: full.status === Image.Error && !page.item.animated
                Icon { anchors.horizontalCenter: parent.horizontalCenter; name: page.item.available ? "broken" : "unavailable"; color: "#BBBBBB"; size: 48 }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: page.item.available ? qsTr("This picture can't be displayed") : qsTr("The drive with this picture is not available")
                    color: "#BBBBBB"
                    font.pixelSize: Theme.fontBody
                }
            }

            WheelHandler {
                target: null
                onWheel: (ev) => page.zoomAt(page.zoom * Math.pow(1.0018, ev.angleDelta.y), point.position.x, point.position.y)
            }
            TapHandler {
                onSingleTapped: viewer.chrome = !viewer.chrome
                onDoubleTapped: (ev) => {
                    if (page.zoomed) { zoomAnim.restart(); page.resetZoom() }
                    else page.animatedZoomAt(2.5, ev.position.x, ev.position.y)
                }
            }
            DragHandler {
                target: null
                enabled: page.zoomed
                property real sx: 0
                property real sy: 0
                onActiveChanged: if (active) { sx = page.panX; sy = page.panY }
                onTranslationChanged: {
                    page.panX = sx + translation.x
                    page.panY = sy + translation.y
                    page.clampPan()
                }
            }
            PinchHandler {
                target: null
                property real startZoom: 1
                onActiveChanged: if (active) startZoom = page.zoom
                onActiveScaleChanged: page.zoomAt(startZoom * activeScale, centroid.position.x, centroid.position.y)
            }
        }
    }

    // shared-element transition image
    Image {
        id: proxy
        visible: false
        asynchronous: false
        smooth: true
        fillMode: Image.PreserveAspectCrop
        clip: true
    }

    ParallelAnimation {
        id: openAnim
        NumberAnimation { id: toX; target: proxy; property: "x"; duration: Theme.durSlow; easing.type: Theme.easing }
        NumberAnimation { id: toY; target: proxy; property: "y"; duration: Theme.durSlow; easing.type: Theme.easing }
        NumberAnimation { id: toW; target: proxy; property: "width"; duration: Theme.durSlow; easing.type: Theme.easing }
        NumberAnimation { id: toH; target: proxy; property: "height"; duration: Theme.durSlow; easing.type: Theme.easing }
        NumberAnimation { target: backdrop; property: "opacity"; to: 1; duration: Theme.durNormal }
        onFinished: {
            pager.opacity = 1
            proxy.visible = false
        }
    }
    ParallelAnimation {
        id: closeAnim
        NumberAnimation { id: backX; target: proxy; property: "x"; duration: Theme.durNormal; easing.type: Theme.easing }
        NumberAnimation { id: backY; target: proxy; property: "y"; duration: Theme.durNormal; easing.type: Theme.easing }
        NumberAnimation { id: backW; target: proxy; property: "width"; duration: Theme.durNormal; easing.type: Theme.easing }
        NumberAnimation { id: backH; target: proxy; property: "height"; duration: Theme.durNormal; easing.type: Theme.easing }
        NumberAnimation { target: backdrop; property: "opacity"; to: 0; duration: Theme.durNormal }
        onFinished: {
            proxy.visible = false
            viewer.visible = false
            viewer.closing = false
        }
    }

    // ---- chrome ----------------------------------------------------------------
    Rectangle {
        id: topBar
        width: parent.width
        height: 72
        y: viewer.chrome && !viewer.closing ? 0 : -height
        Behavior on y { NumberAnimation { duration: Theme.durNormal; easing.type: Theme.easing } }
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.6) }
            GradientStop { position: 1; color: "transparent" }
        }
        IconButton {
            id: closeBtn
            x: Theme.s2
            anchors.verticalCenter: parent.verticalCenter
            icon: "back"
            color: "white"
            onDark: true
            tip: qsTr("Back (Esc)")
            onClicked: viewer.close()
        }
        Column {
            anchors.left: closeBtn.right
            anchors.leftMargin: Theme.s2
            anchors.right: topActions.left
            anchors.verticalCenter: parent.verticalCenter
            Text {
                width: parent.width
                text: viewer.info.date || ""
                elide: Text.ElideRight
                color: "white"
                font.pixelSize: Theme.fontBody
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                text: viewer.info.name || ""
                elide: Text.ElideMiddle
                color: "#CCCCCC"
                font.pixelSize: Theme.fontSmall
            }
        }
        Row {
            id: topActions
            anchors.right: parent.right
            anchors.rightMargin: Theme.s2
            anchors.verticalCenter: parent.verticalCenter
            Text {
                anchors.verticalCenter: parent.verticalCenter
                rightPadding: Theme.s3
                text: viewer.photoModel ? (viewer.currentIndex + 1) + " / " + viewer.photoModel.itemCount : ""
                color: "#CCCCCC"
                font.pixelSize: Theme.fontSmall
            }
            IconButton {
                icon: "more"
                color: "white"
                onDark: true
                onClicked: moreMenu.popup()
                Menu {
                    id: moreMenu
                    MenuItem {
                        text: qsTr("Open Gallery")
                        visible: viewer.win.standalone
                        height: visible ? implicitHeight : 0
                        onTriggered: viewer.win.showLibrary()
                    }
                    MenuItem { text: qsTr("Open with…"); onTriggered: viewer.win.openWith([viewer.info.path]) }
                    MenuItem { text: qsTr("Open in default app"); onTriggered: gallery.openExternally(viewer.info.path) }
                    MenuItem { text: qsTr("Show in folder"); onTriggered: gallery.showInFolder(viewer.info.path) }
                    MenuItem { text: qsTr("Copy path"); onTriggered: gallery.copyPaths([viewer.info.path]) }
                    MenuItem { text: qsTr("Copy to clipboard"); onTriggered: gallery.shareFiles([viewer.info.path]) }
                    MenuItem {
                        text: qsTr("Revert to original")
                        visible: viewer.canRevert
                        height: visible ? implicitHeight : 0
                        onTriggered: viewer.win.confirm(
                            qsTr("Revert to original?"),
                            qsTr("All edits you saved to this picture are removed and the original file is restored."),
                            qsTr("Revert"), function() { editor.revertOriginal(viewer.info.path) })
                    }
                }
            }
        }
    }

    // side arrows for mouse users
    IconButton {
        anchors.left: parent.left
        anchors.leftMargin: Theme.s3
        anchors.verticalCenter: parent.verticalCenter
        visible: viewer.chrome && !viewer.closing && viewer.currentIndex > 0
        icon: "chevronLeft"
        color: "white"
        onDark: true
        iconSize: 28
        width: 52
        height: 52
        onClicked: viewer.go(-1)
    }
    IconButton {
        anchors.right: parent.right
        anchors.rightMargin: Theme.s3
        anchors.verticalCenter: parent.verticalCenter
        visible: viewer.chrome && !viewer.closing && viewer.photoModel && viewer.currentIndex < viewer.photoModel.itemCount - 1
        icon: "chevronRight"
        color: "white"
        onDark: true
        iconSize: 28
        width: 52
        height: 52
        onClicked: viewer.go(1)
    }

    Rectangle {
        id: bottomBar
        width: parent.width
        height: 96
        y: viewer.chrome && !viewer.closing && !viewer.detailsOpen ? parent.height - height : parent.height
        Behavior on y { NumberAnimation { duration: Theme.durNormal; easing.type: Theme.easing } }
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.65) }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.s4
            spacing: Theme.s5
            IconButton {
                icon: "heart"
                visible: viewer.info.external !== true   // only library pictures can be favorites
                filled: viewer.info.favorite === true
                color: viewer.info.favorite ? "#FF5A6E" : "white"
                onDark: true
                tip: qsTr("Favorite (F)")
                onClicked: viewer.toggleFavorite()
            }
            IconButton {
                icon: "edit"
                color: "white"
                onDark: true
                enabled: viewer.info.available === true && viewer.info.animated !== true
                tip: qsTr("Edit (E)")
                onClicked: viewer.win.openEditor(viewer.info)
            }
            IconButton {
                icon: "share"
                color: "white"
                onDark: true
                tip: qsTr("Share (copy file to clipboard)")
                onClicked: gallery.shareFiles([viewer.info.path])
            }
            IconButton {
                icon: "trash"
                color: "white"
                onDark: true
                tip: qsTr("Delete (Del)")
                onClicked: viewer.deleteCurrent()
            }
            IconButton {
                icon: "info"
                color: "white"
                onDark: true
                tip: qsTr("Details (I)")
                onClicked: viewer.detailsOpen = true
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        visible: viewer.detailsOpen
        onClicked: viewer.detailsOpen = false
    }
    DetailsPanel {
        id: details
        info: viewer.info
        width: Math.min(parent.width, 640)
        anchors.horizontalCenter: parent.horizontalCenter
        y: viewer.detailsOpen ? parent.height - height : parent.height + 10
        Behavior on y { NumberAnimation { duration: Theme.durSlow; easing.type: Theme.easing } }
        onCloseRequested: viewer.detailsOpen = false
    }

    Keys.onPressed: (ev) => {
        var page = pager.currentItem
        switch (ev.key) {
        case Qt.Key_Left: viewer.go(-1); break
        case Qt.Key_Right: case Qt.Key_Space: viewer.go(1); break
        case Qt.Key_Home: if (photoModel) pager.currentIndex = 0; break
        case Qt.Key_End: if (photoModel) pager.currentIndex = photoModel.itemCount - 1; break
        case Qt.Key_I: viewer.detailsOpen = !viewer.detailsOpen; break
        case Qt.Key_F: viewer.toggleFavorite(); break
        case Qt.Key_E: if (viewer.info.available && !viewer.info.animated) viewer.win.openEditor(viewer.info); break
        case Qt.Key_Plus: case Qt.Key_Equal:
            if (page) page.animatedZoomAt(page.zoom * 1.5, width / 2, height / 2); break
        case Qt.Key_Minus:
            if (page) page.animatedZoomAt(page.zoom / 1.5, width / 2, height / 2); break
        case Qt.Key_0: if (page) page.resetZoom(); break
        default: return
        }
        ev.accepted = true
    }
}
