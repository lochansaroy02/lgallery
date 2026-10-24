import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "."
import "components"
import "menu"

// Built-in video player: seek bar with time preview, ±10 s skips, volume, playback speed,
// loop, full screen, auto-hiding controls. Keyboard: Space/K play-pause, ←/→ 5 s,
// J/L 10 s, ↑/↓ volume, M mute, F full screen, 0–9 jump to 0–90 %, Esc closes.
// Loaded by Main.qml through a Loader (see components/VideoSurface.qml).
Item {
    id: player
    visible: false
    focus: visible

    property var info: ({})
    property bool controlsShown: true
    property bool muted: false
    property real volume: 1.0
    property real rate: 1.0
    property bool loop: false
    property bool scrubbing: false
    property real scrubValue: 0
    property bool wasFullScreen: false
    readonly property var win: ApplicationWindow.window
    readonly property var video: surface.status === Loader.Ready ? surface.item : null
    readonly property int position: video ? video.position : 0
    readonly property int duration: video && video.duration > 0 ? video.duration : Math.round((info.seconds || 0) * 1000)
    readonly property bool playing: video !== null && video.playing
    readonly property bool fullScreen: win !== null && win.visibility === Window.FullScreen
    readonly property var rates: [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
    signal closed(int position)

    function open(i, startMs) {
        info = i
        rate = 1.0
        muted = false
        controlsShown = true
        scrubbing = false
        wasFullScreen = fullScreen
        opacity = 0
        visible = true
        surface.active = false
        surface.startPosition = Math.max(0, startMs || 0)
        surface.active = true
        fadeIn.restart()
        forceActiveFocus()
        hideTimer.restart()
    }
    // Esc: leave full screen first if the player entered it, then close
    function dismiss() {
        if (fullScreen && !wasFullScreen) win.showNormal()
        else close()
    }
    function close() {
        if (!visible) return
        var pos = position
        if (video) video.pause()
        if (fullScreen && !wasFullScreen) win.showNormal()
        fadeOut.restart()
        closed(pos)
    }
    function togglePlay() {
        if (!video) return
        video.toggle()
        flash.show(video.playing ? "pause" : "play")
        poke()
    }
    function skip(ms) {
        if (!video || duration <= 0) return
        video.seek(position + ms)
        flash.show(ms < 0 ? "skipBack" : "skipForward", Math.abs(ms / 1000) + "")
        poke()
    }
    function seekFraction(f) {
        if (video && duration > 0) video.seek(f * duration)
        poke()
    }
    function changeVolume(delta) {
        volume = Math.max(0, Math.min(1, Math.round((volume + delta) * 20) / 20))
        muted = false
        flash.show("volume", Math.round(volume * 100) + "%")
        poke()
    }
    function toggleMute() {
        muted = !muted
        flash.show(muted ? "volumeOff" : "volume")
        poke()
    }
    // ⋮ menu at the pointer (right-click), kept inside the window
    function openMenuAt(x, y) {
        poke()
        moreMenu.popup(player, Math.max(8, Math.min(x, width - moreMenu.width - 8)),
                               Math.max(8, Math.min(y, height - moreMenu.height - 8)))
    }
    function captureFrame() {
        if (!info.path || !gallery.videoThumbnailsSupported || info.private) return
        gallery.captureFrame(info.path, position)
        flash.show("camera")
        shutter.restart()
        poke()
    }
    function toggleFullScreen() {
        if (fullScreen) win.showNormal()
        else win.showFullScreen()
        poke()
    }
    // any user activity shows the controls; they hide again while playing
    function poke() {
        controlsShown = true
        hideTimer.restart()
    }

    NumberAnimation on opacity { id: fadeIn; running: false; to: 1; duration: Theme.durNormal }
    SequentialAnimation {
        id: fadeOut
        NumberAnimation { target: player; property: "opacity"; to: 0; duration: Theme.durNormal }
        ScriptAction { script: { player.visible = false; surface.active = false } }
    }
    Timer {
        id: hideTimer
        interval: 2600
        onTriggered: {
            if (player.playing && !player.scrubbing && !topHover.hovered && !bottomHover.hovered
                    && !speedMenu.visible && !moreMenu.visible)
                player.controlsShown = false
        }
    }

    Rectangle { anchors.fill: parent; color: "black" }

    // poster until the first frame is decoded
    Image {
        anchors.fill: parent
        source: player.visible ? (player.info.full || "") : ""
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        visible: !(player.video && player.video.frameShown)
        sourceSize: Qt.size(Math.min(1920, Screen.width), Math.min(1920, Screen.height))
    }

    Loader {
        id: surface
        anchors.fill: parent
        active: false
        source: "components/VideoSurface.qml"
        property int startPosition: 0
        onLoaded: {
            item.autoPlay = true
            item.startPosition = startPosition
            item.source = player.info.url
        }
        Binding { target: surface.item; when: surface.status === Loader.Ready; property: "muted"; value: player.muted }
        Binding { target: surface.item; when: surface.status === Loader.Ready; property: "volume"; value: player.volume }
        Binding { target: surface.item; when: surface.status === Loader.Ready; property: "playbackRate"; value: player.rate }
        Binding { target: surface.item; when: surface.status === Loader.Ready; property: "loops"; value: player.loop }
    }

    // click: play / pause, double-click: full screen, moving the mouse shows the controls
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: player.controlsShown ? Qt.ArrowCursor : Qt.BlankCursor
        onPositionChanged: player.poke()
        onClicked: (m) => {
            if (m.button === Qt.RightButton) player.openMenuAt(m.x, m.y)
            else clickTimer.restart()
        }
        onDoubleClicked: (m) => { if (m.button === Qt.LeftButton) { clickTimer.stop(); player.toggleFullScreen() } }
        onWheel: (ev) => player.changeVolume(ev.angleDelta.y > 0 ? 0.05 : -0.05)
        Timer { id: clickTimer; interval: 220; onTriggered: player.togglePlay() }
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: player.video !== null && player.video.loading && player.video.errorString === ""
        visible: running
    }

    // big replay button at the end, error message when the codec is not supported
    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - 2 * Theme.s5, 460)
        spacing: Theme.s3
        visible: surface.status === Loader.Error || (player.video !== null && player.video.errorString !== "")
        Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "video"; color: "#BBBBBB"; size: 52 }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: surface.status === Loader.Error
                  ? qsTr("Playing videos needs Qt Multimedia (sudo pacman -S qt6-multimedia qt6-multimedia-ffmpeg).")
                  : qsTr("This video can't be played.") + "\n" + (player.video ? player.video.errorString : "")
            color: "#DDDDDD"
            font.pixelSize: Theme.fontBody
        }
        PillButton {
            anchors.horizontalCenter: parent.horizontalCenter
            kind: "tonal"
            text: qsTr("Open in default app")
            icon: "openWith"
            onClicked: gallery.openExternally(player.info.path)
        }
    }
    Rectangle {
        anchors.centerIn: parent
        width: 84
        height: 84
        radius: 42
        color: Qt.rgba(0, 0, 0, 0.45)
        visible: player.video !== null && player.video.ended && !player.loop
        Icon { anchors.centerIn: parent; name: "skipBack"; color: "white"; size: 34 }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: { player.video.play(); player.poke() }
        }
    }

    // camera-style flash when a frame is captured
    Rectangle {
        id: shutterRect
        anchors.fill: parent
        color: "white"
        opacity: 0
        visible: opacity > 0
        SequentialAnimation {
            id: shutter
            NumberAnimation { target: shutterRect; property: "opacity"; to: 0.5; duration: 60 }
            NumberAnimation { target: shutterRect; property: "opacity"; to: 0; duration: Theme.durSlow; easing.type: Easing.OutQuad }
        }
    }

    // short feedback bubble for keyboard / click actions
    Rectangle {
        id: flash
        anchors.centerIn: parent
        width: Math.max(88, flashRow.implicitWidth + 2 * Theme.s4)
        height: 88
        radius: 44
        color: Qt.rgba(0, 0, 0, 0.5)
        opacity: 0
        property string icon: "play"
        property string label: ""
        function show(name, text) {
            icon = name
            label = text || ""
            flashAnim.restart()
        }
        Row {
            id: flashRow
            anchors.centerIn: parent
            spacing: Theme.s2
            Icon { anchors.verticalCenter: parent.verticalCenter; name: flash.icon; filled: flash.icon === "play" || flash.icon === "pause"; color: "white"; size: 34 }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: flash.label !== ""
                text: flash.label
                color: "white"
                font.pixelSize: Theme.fontLarge
                font.weight: Font.DemiBold
            }
        }
        SequentialAnimation {
            id: flashAnim
            NumberAnimation { target: flash; property: "opacity"; to: 1; duration: 80 }
            PauseAnimation { duration: 380 }
            NumberAnimation { target: flash; property: "opacity"; to: 0; duration: Theme.durSlow }
        }
    }

    // ---- controls -------------------------------------------------------------------------------
    Item {
        id: chrome
        anchors.fill: parent
        opacity: player.controlsShown || !player.playing ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.durNormal } }

        Rectangle {
            id: topBar
            width: parent.width
            height: 76
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.65) }
                GradientStop { position: 1; color: "transparent" }
            }
            HoverHandler { id: topHover; onHoveredChanged: if (hovered) player.poke() }
            IconButton {
                id: backButton
                x: Theme.s2
                anchors.verticalCenter: parent.verticalCenter
                icon: "back"
                color: "white"
                onDark: true
                tip: qsTr("Back (Esc)")
                onClicked: player.close()
            }
            Column {
                anchors.left: backButton.right
                anchors.leftMargin: Theme.s2
                anchors.right: topActions.left
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    width: parent.width
                    text: player.info.name || ""
                    elide: Text.ElideMiddle
                    color: "white"
                    font.pixelSize: Theme.fontBody
                    font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width
                    text: [player.info.date || "", player.info.width > 0 ? player.info.width + " × " + player.info.height : "",
                           player.info.size || ""].filter(s => s !== "").join("  ·  ")
                    elide: Text.ElideRight
                    color: "#CCCCCC"
                    font.pixelSize: Theme.fontSmall
                }
            }
            Row {
                id: topActions
                anchors.right: parent.right
                anchors.rightMargin: Theme.s2
                anchors.verticalCenter: parent.verticalCenter
                IconButton {
                    icon: "repeat"
                    color: player.loop ? Theme.accent : "white"
                    onDark: true
                    tip: player.loop ? qsTr("Loop: on") : qsTr("Loop: off")
                    onClicked: { player.loop = !player.loop; player.poke() }
                }
                IconButton {
                    id: moreButton
                    icon: "more"
                    color: "white"
                    onDark: true
                    tip: qsTr("More options")
                    onClicked: moreMenu.popup(moreButton, moreButton.width - moreMenu.width, moreButton.height + 4)
                    StyledMenu {
                        id: moreMenu
                        AppMenuItem { text: qsTr("Open with…"); iconName: "openWith"; visible: !player.info.private; onTriggered: player.win.openWith([player.info.path]) }
                        AppMenuItem { text: qsTr("Open in default app"); iconName: "monitor"; visible: !player.info.private; onTriggered: gallery.openExternally(player.info.path) }
                        AppMenuItem { text: qsTr("Show in folder"); iconName: "showFolder"; visible: !player.info.private; onTriggered: gallery.showInFolder(player.info.path) }
                        AppMenuItem {
                            text: qsTr("Capture frame"); iconName: "camera"; shortcutText: "S"
                            visible: !player.info.private
                            enabled: gallery.videoThumbnailsSupported
                            onTriggered: player.captureFrame()
                        }
                        MenuDivider { }
                        AppMenuItem { text: qsTr("Copy video"); iconName: "copy"; visible: !player.info.private; onTriggered: gallery.shareFiles([player.info.path]) }
                        AppMenuItem { text: qsTr("Copy path"); iconName: "file"; visible: !player.info.private; onTriggered: gallery.copyPaths([player.info.path]) }
                    }
                }
            }
        }

        Rectangle {
            id: bottomBar
            anchors.bottom: parent.bottom
            width: parent.width
            height: 132
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.72) }
            }
            HoverHandler { id: bottomHover; onHoveredChanged: if (hovered) player.poke() }

            // seek bar
            Item {
                id: seekRow
                x: Theme.s5
                width: parent.width - 2 * Theme.s5
                y: 36
                height: 28
                Text {
                    id: posText
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: player.win.formatTime(player.scrubbing ? player.scrubValue * player.duration : player.position)
                    color: "white"
                    font.pixelSize: Theme.fontSmall
                }
                Text {
                    id: durText
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: player.win.formatTime(player.duration)
                    color: "#CCCCCC"
                    font.pixelSize: Theme.fontSmall
                }
                Slider {
                    id: seek
                    focusPolicy: Qt.NoFocus
                    anchors.left: posText.right
                    anchors.right: durText.left
                    anchors.leftMargin: Theme.s3
                    anchors.rightMargin: Theme.s3
                    anchors.verticalCenter: parent.verticalCenter
                    from: 0
                    to: 1
                    enabled: player.duration > 0 && player.video !== null && player.video.seekable
                    value: player.scrubbing ? player.scrubValue : (player.duration > 0 ? player.position / player.duration : 0)
                    live: true
                    onMoved: {
                        player.scrubValue = value
                        if (player.video) player.video.seek(value * player.duration)
                        player.poke()
                    }
                    onPressedChanged: {
                        player.scrubbing = pressed
                        if (pressed) player.scrubValue = value
                        player.poke()
                    }
                    background: Item {
                        x: seek.leftPadding
                        y: seek.topPadding + seek.availableHeight / 2 - height / 2
                        width: seek.availableWidth
                        height: seek.hovered || seek.pressed ? 6 : 4
                        Behavior on height { NumberAnimation { duration: Theme.durFast } }
                        Rectangle { anchors.fill: parent; radius: height / 2; color: Qt.rgba(1, 1, 1, 0.3) }
                        Rectangle {
                            width: seek.visualPosition * parent.width
                            height: parent.height
                            radius: height / 2
                            color: Theme.accent
                        }
                    }
                    handle: Rectangle {
                        x: seek.leftPadding + seek.visualPosition * (seek.availableWidth - width)
                        y: seek.topPadding + seek.availableHeight / 2 - height / 2
                        width: seek.pressed ? 18 : 14
                        height: width
                        radius: width / 2
                        color: "white"
                        Behavior on width { NumberAnimation { duration: Theme.durFast } }
                    }
                    // time bubble while scrubbing / hovering
                    Rectangle {
                        id: bubble
                        readonly property real at: seek.pressed ? seek.visualPosition : hoverAt
                        property real hoverAt: 0
                        visible: (seek.pressed || seekHover.hovered) && player.duration > 0
                        width: bubbleText.implicitWidth + 16
                        height: 26
                        radius: 13
                        color: Qt.rgba(0.1, 0.1, 0.12, 0.92)
                        x: Math.max(0, Math.min(seek.width - width, seek.leftPadding + at * seek.availableWidth - width / 2))
                        y: -height - 6
                        Text {
                            id: bubbleText
                            anchors.centerIn: parent
                            text: player.win.formatTime(bubble.at * player.duration)
                            color: "white"
                            font.pixelSize: Theme.fontSmall
                        }
                    }
                    HoverHandler {
                        id: seekHover
                        onPointChanged: bubble.hoverAt = Math.max(0, Math.min(1, (point.position.x - seek.leftPadding) / seek.availableWidth))
                    }
                }
            }

            // buttons
            Item {
                x: Theme.s4
                width: parent.width - 2 * Theme.s4
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.s3
                height: 56

                Row {
                    id: leftGroup
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.s1
                    IconButton {
                        icon: player.muted || player.volume === 0 ? "volumeOff" : "volume"
                        color: "white"
                        onDark: true
                        tip: player.muted ? qsTr("Unmute (M)") : qsTr("Mute (M)")
                        onClicked: player.toggleMute()
                    }
                    Slider {
                        id: volumeSlider
                    focusPolicy: Qt.NoFocus
                        anchors.verticalCenter: parent.verticalCenter
                        width: player.width > 640 ? 110 : 0
                        visible: width > 0
                        from: 0
                        to: 1
                        value: player.muted ? 0 : player.volume
                        onMoved: { player.volume = value; player.muted = value === 0; player.poke() }
                        background: Rectangle {
                            x: volumeSlider.leftPadding
                            y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                            width: volumeSlider.availableWidth
                            height: 4
                            radius: 2
                            color: Qt.rgba(1, 1, 1, 0.3)
                            Rectangle { width: volumeSlider.visualPosition * parent.width; height: parent.height; radius: 2; color: "white" }
                        }
                        handle: Rectangle {
                            x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                            y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                            width: 12
                            height: 12
                            radius: 6
                            color: "white"
                        }
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.s4
                    component SkipButton: Item {
                        id: skipBtn
                        property string icon
                        property string tip
                        signal clicked()
                        width: 48
                        height: 48
                        IconButton {
                            anchors.fill: parent
                            icon: skipBtn.icon
                            color: "white"
                            onDark: true
                            iconSize: 28
                            tip: skipBtn.tip
                            onClicked: skipBtn.clicked()
                        }
                        Text {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: 1
                            text: "10"
                            color: "white"
                            font.pixelSize: 9
                            font.weight: Font.Bold
                        }
                    }
                    SkipButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "skipBack"
                        tip: qsTr("Back 10 seconds (J)")
                        onClicked: player.skip(-10000)
                    }
                    Rectangle {
                        width: 56
                        height: 56
                        radius: 28
                        color: playMouse.pressed ? Qt.rgba(1, 1, 1, 0.9) : "white"
                        Icon {
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: player.playing ? 0 : 2
                            name: player.playing ? "pause" : "play"
                            filled: true
                            strokeWidth: 1
                            color: "black"
                            size: 22
                        }
                        MouseArea {
                            id: playMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: player.togglePlay()
                        }
                        ToolTip.visible: playMouse.containsMouse
                        ToolTip.text: player.playing ? qsTr("Pause (Space)") : qsTr("Play (Space)")
                    }
                    SkipButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "skipForward"
                        tip: qsTr("Forward 10 seconds (L)")
                        onClicked: player.skip(10000)
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.s1
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: speedText.implicitWidth + 20
                        height: 32
                        radius: 16
                        color: speedMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.1)
                        Text {
                            id: speedText
                            anchors.centerIn: parent
                            text: player.rate + "×"
                            color: player.rate !== 1 ? Theme.accent : "white"
                            font.pixelSize: Theme.fontSmall
                            font.weight: Font.DemiBold
                        }
                        MouseArea {
                            id: speedMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: speedMenu.popup(parent, 0, -speedMenu.implicitHeight - 4)
                        }
                        ToolTip.visible: speedMouse.containsMouse && !speedMenu.visible
                        ToolTip.delay: 600
                        ToolTip.text: qsTr("Playback speed ([ and ])")
                        StyledMenu {
                            id: speedMenu
                            Instantiator {
                                model: player.rates
                                onObjectAdded: (i, obj) => speedMenu.insertItem(i, obj)
                                onObjectRemoved: (i, obj) => speedMenu.removeItem(obj)
                                delegate: AppMenuItem {
                                    required property real modelData
                                    text: modelData === 1 ? qsTr("Normal") : modelData + "×"
                                    checkable: true
                                    checked: player.rate === modelData
                                    onTriggered: player.rate = modelData
                                }
                            }
                        }
                    }
                    IconButton {
                        icon: "camera"
                        visible: player.info.private !== true
                        color: "white"
                        onDark: true
                        enabled: gallery.videoThumbnailsSupported
                        tip: gallery.videoThumbnailsSupported ? qsTr("Capture this frame (S)")
                                                              : qsTr("Capturing frames needs ffmpeg")
                        onClicked: player.captureFrame()
                    }
                    IconButton {
                        icon: player.fullScreen ? "fullscreenExit" : "fullscreen"
                        color: "white"
                        onDark: true
                        tip: player.fullScreen ? qsTr("Exit full screen (F)") : qsTr("Full screen (F)")
                        onClicked: player.toggleFullScreen()
                    }
                }
            }
        }
    }

    function stepRate(dir) {
        var i = rates.indexOf(rate)
        if (i < 0) i = 3
        i = Math.max(0, Math.min(rates.length - 1, i + dir))
        rate = rates[i]
        flash.show("gauge", rate + "×")
        poke()
    }

    Keys.onPressed: (ev) => {
        switch (ev.key) {
        case Qt.Key_Space: case Qt.Key_K: case Qt.Key_MediaTogglePlayPause: case Qt.Key_MediaPlay:
            player.togglePlay(); break
        case Qt.Key_Left: player.skip(-5000); break
        case Qt.Key_Right: player.skip(5000); break
        case Qt.Key_J: player.skip(-10000); break
        case Qt.Key_L: player.skip(10000); break
        case Qt.Key_Up: player.changeVolume(0.05); break
        case Qt.Key_Down: player.changeVolume(-0.05); break
        case Qt.Key_M: player.toggleMute(); break
        case Qt.Key_S: player.captureFrame(); break
        case Qt.Key_F: player.toggleFullScreen(); break
        case Qt.Key_BracketLeft: player.stepRate(-1); break
        case Qt.Key_BracketRight: player.stepRate(1); break
        case Qt.Key_Home: player.seekFraction(0); break
        case Qt.Key_End: player.seekFraction(0.999); break
        case Qt.Key_Escape: case Qt.Key_Back: player.dismiss(); break
        default:
            if (ev.key >= Qt.Key_0 && ev.key <= Qt.Key_9 && !(ev.modifiers & Qt.ControlModifier)) {
                player.seekFraction((ev.key - Qt.Key_0) / 10)
                break
            }
            return
        }
        ev.accepted = true
    }
}
