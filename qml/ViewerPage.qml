import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "."
import "components"
import "menu"

// Full-screen viewer: swipe / arrow keys to navigate, wheel / double-click / pinch
// to zoom, drag to pan, Esc to close. Opens and closes with a shared-element
// transition from the grid thumbnail. Videos start playing muted right away; "Play video"
// (or Enter / double-click) opens them in the video player with sound.
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
    property bool videoMuted: true    // inline video previews start muted
    property bool playerOpen: false   // the video player is showing the current video
    readonly property alias moreMenu: moreMenu
    readonly property alias captureButton: captureButton
    property int resumeAt: 0          // continue the preview where the player stopped...
    property string resumePath: ""    // ...for this video only
    function resumeFrom(path, ms) { resumePath = path; resumeAt = ms }
    readonly property bool isVideo: info.video === true
    readonly property var preview: pager.currentItem ? pager.currentItem.preview : null

    function playCurrent() {
        if (!isVideo || !info.path) return
        win.playVideo(info, preview ? preview.position : 0)
    }
    function toggleMute() { videoMuted = !videoMuted }
    // save the frame on screen as a picture next to the video (full resolution, via ffmpeg)
    function captureFrame() {
        if (!isVideo || !info.path || info.available !== true || info.private) return
        var ms = preview ? preview.position : resumeAt
        gallery.captureFrame(info.path, ms)
        resumeFrom(info.path, ms)    // the library reloads with the new picture: keep playing from here
        captureFlash.restart()
    }
    // ⋮ menu at a point (right-click), kept inside the window
    function openMenuAt(x, y) {
        if (closing || !info.path) return
        chrome = true
        moreMenu.popup(viewer, Math.max(8, Math.min(x, width - moreMenu.width - 8)),
                               Math.max(8, Math.min(y, height - moreMenu.height - 8)))
    }
    function openMenuFromButton() {
        moreMenu.popup(moreButton, moreButton.width - moreMenu.width, moreButton.height + 4)
    }

    function refreshInfo() {
        info = photoModel && currentIndex >= 0 && currentIndex < photoModel.itemCount
               ? photoModel.itemAt(currentIndex) : ({})
        canRevert = info.path && !info.private ? editor.hasOriginal(info.path) : false
        if (info.path && !info.private) gallery.prepareShare([info.path])   // warm up the share menu
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
        videoMuted = true
        resumeFrom("", 0)
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
    function goTo(index) {
        if (photoModel && index >= 0 && index < photoModel.itemCount) pager.currentIndex = index
    }
    function zoomStep(factor) {
        var page = pager.currentItem
        if (page) page.animatedZoomAt(page.zoom * factor, width / 2, height / 2)
    }
    function fit() {
        var page = pager.currentItem
        if (page) page.resetZoom()
    }

    function deleteCurrent() {
        if (!info.path) return
        if (info.private) win.deletePrivate([info.id], null)
        else win.confirmDelete([info.path], null)
    }
    function moveCurrentToPrivate() {
        if (info.path && !info.private) win.moveToPrivate([info.path], null)
    }
    function moveCurrentOutOfPrivate() {
        if (info.private) win.moveOutOfPrivate([info.id], null)
    }

    function toggleFavorite() {
        if (info.id === undefined || info.external) return
        gallery.setFavorite([info.id], !info.favorite)
    }

    // a private video was decrypted for playback: its URL is now known
    Connections {
        target: privateAlbum
        function onVideoPrepared(id) { viewer.revision++; viewer.refreshInfo() }
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
            readonly property bool isVideo: item.video === true
            readonly property var preview: inlineVideo.status === Loader.Ready ? inlineVideo.item : null
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
                if (isVideo) return
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
                // the current video plays muted and loops; the poster above shows until the
                // first frame arrives
                Loader {
                    id: inlineVideo
                    anchors.fill: parent
                    active: page.isVideo && page.item.available === true && page.isCurrent
                            && viewer.visible && !viewer.closing && !viewer.playerOpen
                            && (page.item.url || "") !== ""
                    source: "components/VideoSurface.qml"
                    opacity: status === Loader.Ready && item && item.frameShown ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.durNormal } }
                    onLoaded: {
                        item.loops = true
                        item.startPosition = viewer.resumePath === page.item.path ? viewer.resumeAt : 0
                        viewer.resumeAt = 0
                        viewer.resumePath = ""
                        item.source = page.item.url
                    }
                    Binding {
                        target: inlineVideo.item
                        when: inlineVideo.status === Loader.Ready
                        property: "muted"
                        value: viewer.videoMuted
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                width: Math.min(parent.width - 2 * Theme.s5, 420)
                spacing: Theme.s3
                visible: page.isVideo && page.isCurrent && (inlineVideo.status === Loader.Error
                         || (page.preview !== null && page.preview.errorString !== ""))
                Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "video"; color: "#BBBBBB"; size: 48 }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: inlineVideo.status === Loader.Error
                          ? qsTr("Playing videos needs Qt Multimedia (sudo pacman -S qt6-multimedia qt6-multimedia-ffmpeg).")
                          : qsTr("This video can't be played here.")
                    color: "#BBBBBB"
                    font.pixelSize: Theme.fontBody
                }
                PillButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    kind: "tonal"
                    text: qsTr("Open in default app")
                    icon: "openWith"
                    onClicked: gallery.openExternally(page.item.path)
                }
            }
            Column {
                anchors.centerIn: parent
                spacing: Theme.s3
                visible: full.status === Image.Error && !page.item.animated && !page.isVideo
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
                enabled: !page.isVideo
                onWheel: (ev) => page.zoomAt(page.zoom * Math.pow(1.0018, ev.angleDelta.y), point.position.x, point.position.y)
            }
            // right-click (or long-press on a touch screen): the ⋮ menu at the pointer
            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: (ev) => {
                    var p = page.mapToItem(viewer, ev.position.x, ev.position.y)
                    viewer.openMenuAt(p.x, p.y)
                }
            }
            TapHandler {
                acceptedDevices: PointerDevice.TouchScreen
                onLongPressed: {
                    var p = page.mapToItem(viewer, point.position.x, point.position.y)
                    viewer.openMenuAt(p.x, p.y)
                }
            }
            TapHandler {
                onSingleTapped: viewer.chrome = !viewer.chrome
                onDoubleTapped: (ev) => {
                    if (page.isVideo) viewer.playCurrent()
                    else if (page.zoomed) { zoomAnim.restart(); page.resetZoom() }
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
                enabled: !page.isVideo
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
                id: moreButton
                icon: "more"
                color: "white"
                onDark: true
                tip: qsTr("More options")
                onClicked: viewer.openMenuFromButton()
                ViewerMenu {
                    id: moreMenu
                    viewer: viewer
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
                icon: "unlock"
                visible: viewer.info.private === true
                color: "white"
                onDark: true
                tip: qsTr("Move out of the private album")
                onClicked: viewer.moveCurrentOutOfPrivate()
            }
            IconButton {
                icon: "edit"
                visible: viewer.info.private !== true
                color: "white"
                onDark: true
                enabled: viewer.info.available === true && viewer.info.animated !== true && !viewer.isVideo
                tip: viewer.isVideo ? qsTr("Videos can't be edited here") : qsTr("Edit (E)")
                onClicked: viewer.win.openEditor(viewer.info)
            }
            IconButton {
                id: shareButton
                visible: viewer.info.private !== true
                icon: "share"
                color: "white"
                onDark: true
                tip: qsTr("Share")
                onClicked: viewer.win.share([viewer.info.path], shareButton)
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

    // inline video: mute toggle (muted by default) and "Play video" for the full player
    Item {
        id: videoControls
        width: parent.width
        height: 48
        y: bottomBar.y - height + Theme.s2
        visible: viewer.isVideo && !viewer.closing
        opacity: viewer.chrome && !viewer.detailsOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durNormal } }

        Rectangle {
            id: playPill
            anchors.centerIn: parent
            height: 44
            width: playRow.implicitWidth + 2 * Theme.s5
            radius: height / 2
            color: playMouse.pressed ? Qt.rgba(0.25, 0.25, 0.28, 0.8) : playMouse.containsMouse ? Qt.rgba(0.18, 0.18, 0.2, 0.72) : Qt.rgba(0, 0, 0, 0.55)
            border.color: Qt.rgba(1, 1, 1, 0.22)
            Row {
                id: playRow
                anchors.centerIn: parent
                spacing: Theme.s2
                Icon { anchors.verticalCenter: parent.verticalCenter; name: "play"; filled: true; color: "white"; size: 16 }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Play video")
                    color: "white"
                    font.pixelSize: Theme.fontBody
                    font.weight: Font.DemiBold
                }
            }
            MouseArea {
                id: playMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: viewer.playCurrent()
            }
            ToolTip.visible: playMouse.containsMouse
            ToolTip.delay: 600
            ToolTip.text: qsTr("Play with sound in the video player (Enter)")
        }
        Rectangle {
            anchors.left: playPill.right
            anchors.leftMargin: Theme.s3
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            height: 44
            radius: 22
            color: Qt.rgba(0, 0, 0, 0.55)
            border.color: Qt.rgba(1, 1, 1, 0.22)
            IconButton {
                id: muteButton
                anchors.fill: parent
                icon: viewer.videoMuted ? "volumeOff" : "volume"
                color: "white"
                onDark: true
                iconSize: 20
                tip: viewer.videoMuted ? qsTr("Unmute (M)") : qsTr("Mute (M)")
                onClicked: viewer.toggleMute()
            }
        }
        Rectangle {
            id: captureRound
            visible: viewer.info.private !== true
            x: playPill.x + playPill.width + Theme.s3 + 44 + Theme.s2
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            height: 44
            radius: 22
            color: Qt.rgba(0, 0, 0, 0.55)
            border.color: Qt.rgba(1, 1, 1, 0.22)
            IconButton {
                id: captureButton
                anchors.fill: parent
                icon: "camera"
                color: "white"
                onDark: true
                iconSize: 20
                enabled: viewer.info.available === true && gallery.videoThumbnailsSupported && !viewer.info.private
                tip: gallery.videoThumbnailsSupported ? qsTr("Capture this frame (S)")
                                                      : qsTr("Capturing frames needs ffmpeg")
                onClicked: viewer.captureFrame()
            }
        }
        Rectangle {
            anchors.right: playPill.left
            anchors.rightMargin: Theme.s3
            anchors.verticalCenter: parent.verticalCenter
            visible: viewer.preview !== null && viewer.preview.duration > 0
            width: timeText.implicitWidth + 2 * Theme.s3
            height: 30
            radius: 15
            color: Qt.rgba(0, 0, 0, 0.55)
            Text {
                id: timeText
                anchors.centerIn: parent
                text: viewer.preview ? viewer.win.formatTime(viewer.preview.position) + " / "
                                       + viewer.win.formatTime(viewer.preview.duration) : ""
                color: "#E5E5EA"
                font.pixelSize: Theme.fontSmall
            }
        }
    }
    // preview progress along the bottom edge
    Rectangle {
        anchors.bottom: parent.bottom
        height: 3
        visible: viewer.isVideo && viewer.preview !== null && viewer.preview.duration > 0 && !viewer.closing
        width: visible ? parent.width * viewer.preview.position / viewer.preview.duration : 0
        color: Theme.accent
    }

    // camera-style flash when a frame is captured
    Rectangle {
        id: flashRect
        anchors.fill: parent
        color: "white"
        opacity: 0
        visible: opacity > 0
        SequentialAnimation {
            id: captureFlash
            NumberAnimation { target: flashRect; property: "opacity"; to: 0.55; duration: 60 }
            NumberAnimation { target: flashRect; property: "opacity"; to: 0; duration: Theme.durSlow; easing.type: Easing.OutQuad }
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
        case Qt.Key_E: if (viewer.info.available && !viewer.info.animated && !viewer.isVideo && !viewer.info.private) viewer.win.openEditor(viewer.info); break
        case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_P: viewer.playCurrent(); break
        case Qt.Key_M: if (viewer.isVideo) viewer.toggleMute(); break
        case Qt.Key_S: if (viewer.isVideo) viewer.captureFrame(); break
        case Qt.Key_Menu: viewer.openMenuFromButton(); break
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
