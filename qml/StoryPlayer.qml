import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Window
import "."
import "components"

// Full-screen story slideshow (Google Photos style memories):
// progress bars, slow Ken Burns zoom/pan, crossfades. Tap left/right half to go
// back/forward, press and hold to pause, Space pauses, Esc closes.
Item {
    id: player
    visible: false
    focus: visible

    property var story: null
    property int index: 0
    property bool paused: false
    property bool frontA: true
    readonly property int slideMs: 5000
    readonly property var items: story ? story.items : []
    readonly property var current: index >= 0 && index < items.length ? items[index] : null
    signal openPicture(string path)

    function play(s) {
        if (!s || !s.items || s.items.length === 0) return
        story = s
        index = 0
        paused = false
        opacity = 0
        visible = true
        fadeIn.start()
        forceActiveFocus()
        show(true)
    }
    function close() {
        clock.stop()
        fadeOut.start()
    }
    function next() {
        if (index < items.length - 1) { index++; show(false) }
        else close()
    }
    function prev() {
        if (index > 0) index--
        show(false)
    }
    function togglePause() { paused = !paused }

    function show(first) {
        var target = frontA ? layerB : layerA
        if (first) target = frontA ? layerA : layerB
        target.source = current ? current.full : ""
        target.restartMotion(index)
        if (!first) frontA = !frontA
        clock.restart()
        // warm the cache for the next picture
        preload.source = index + 1 < items.length ? items[index + 1].full : ""
    }

    onPausedChanged: paused ? clock.pause() : clock.resume()

    NumberAnimation on opacity { id: fadeIn; running: false; to: 1; duration: Theme.durSlow }
    SequentialAnimation {
        id: fadeOut
        NumberAnimation { target: player; property: "opacity"; to: 0; duration: Theme.durNormal }
        ScriptAction { script: { player.visible = false; player.story = null; layerA.source = ""; layerB.source = "" } }
    }

    // drives the slide timing and the progress bar
    NumberAnimation {
        id: clock
        target: progressHolder
        property: "value"
        from: 0
        to: 1
        duration: player.slideMs
        onFinished: if (player.visible && !player.paused) player.next()
    }
    QtObject { id: progressHolder; property real value: 0 }

    Rectangle { anchors.fill: parent; color: "black" }

    component Slide: Item {
        id: slide
        property alias source: photo.source
        property bool front: false
        anchors.fill: parent
        opacity: front ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.InOutQuad } }

        // blurred, cropped copy behind the picture fills the screen
        Image {
            id: backdrop
            anchors.fill: parent
            source: photo.source
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
            sourceSize: Qt.size(480, 480)
        }
        MultiEffect {
            anchors.fill: parent
            source: backdrop
            blurEnabled: true
            blurMax: 64
            blur: 1.0
            brightness: -0.25
            opacity: 0.6
        }
        Item {
            id: motion
            anchors.fill: parent
            Image {
                id: photo
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
                mipmap: true
                sourceSize: Qt.size(Math.min(3840, Screen.width * Screen.devicePixelRatio),
                                    Math.min(3840, Screen.height * Screen.devicePixelRatio))
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 300 } }
            }
        }
        ParallelAnimation {
            id: kenBurns
            NumberAnimation { id: zoom; target: motion; property: "scale"; duration: player.slideMs + 900 }
            NumberAnimation { id: panX; target: motion; property: "x"; duration: player.slideMs + 900 }
            NumberAnimation { id: panY; target: motion; property: "y"; duration: player.slideMs + 900 }
        }
        // a different gentle move for every picture: zoom in or out, drift a little
        function restartMotion(i) {
            kenBurns.stop()
            var zoomIn = i % 2 === 0
            var dx = [18, -18, 12, -12][i % 4], dy = [-10, 10, 8, -8][(i + 1) % 4]
            zoom.from = zoomIn ? 1.0 : 1.1; zoom.to = zoomIn ? 1.1 : 1.0
            panX.from = zoomIn ? 0 : dx; panX.to = zoomIn ? dx : 0
            panY.from = zoomIn ? 0 : dy; panY.to = zoomIn ? dy : 0
            kenBurns.start()
        }
        Connections {
            target: player
            function onPausedChanged() { player.paused ? kenBurns.pause() : kenBurns.resume() }
        }
    }

    Slide { id: layerA; front: player.frontA }
    Slide { id: layerB; front: !player.frontA }
    Image { id: preload; visible: false; asynchronous: true; sourceSize: Qt.size(Screen.width, Screen.height) }

    // tap zones: left third = back, rest = next; hold anywhere = pause
    MouseArea {
        anchors.fill: parent
        pressAndHoldInterval: 250
        property bool held: false
        onPressAndHold: { held = true; player.paused = true }
        onReleased: (m) => {
            if (held) { held = false; player.paused = false; return }
        }
        onClicked: (m) => { if (m.x < width / 3) player.prev(); else player.next() }
    }

    // ---- top chrome ---------------------------------------------------------------------------
    Rectangle {
        width: parent.width
        height: 140
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.55) }
            GradientStop { position: 1; color: "transparent" }
        }
    }
    Row {
        id: bars
        x: Theme.s4
        y: Theme.s3
        width: parent.width - 2 * Theme.s4
        spacing: 4
        Repeater {
            model: player.items.length
            delegate: Rectangle {
                required property int index
                width: (bars.width - bars.spacing * (player.items.length - 1)) / Math.max(1, player.items.length)
                height: 3
                radius: 1.5
                color: Qt.rgba(1, 1, 1, 0.35)
                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    color: "white"
                    width: parent.width * (index < player.index ? 1 : index === player.index ? progressHolder.value : 0)
                }
            }
        }
    }
    Column {
        x: Theme.s5
        anchors.top: bars.bottom
        anchors.topMargin: Theme.s3
        spacing: 2
        Text {
            text: player.story ? player.story.title : ""
            color: "white"
            font.pixelSize: Theme.fontTitle + 2
            font.weight: Font.Bold
        }
        Text {
            text: player.current ? player.current.date : ""
            color: "#E5E5EA"
            font.pixelSize: Theme.fontSmall + 1
        }
    }
    Row {
        anchors.right: parent.right
        anchors.rightMargin: Theme.s3
        anchors.top: bars.bottom
        anchors.topMargin: Theme.s2
        IconButton {
            icon: player.paused ? "play" : "pause"
            filled: true
            color: "white"
            onDark: true
            tip: player.paused ? qsTr("Play (Space)") : qsTr("Pause (Space)")
            onClicked: player.togglePause()
        }
        IconButton {
            icon: "pictures"
            color: "white"
            onDark: true
            tip: qsTr("Open this picture")
            onClicked: if (player.current) { var path = player.current.path; player.close(); player.openPicture(path) }
        }
        IconButton {
            icon: "close"
            color: "white"
            onDark: true
            tip: qsTr("Close (Esc)")
            onClicked: player.close()
        }
    }

    Keys.onPressed: (ev) => {
        switch (ev.key) {
        case Qt.Key_Left: player.prev(); break
        case Qt.Key_Right: player.next(); break
        case Qt.Key_Space: player.togglePause(); break
        case Qt.Key_Escape: player.close(); break
        default: return
        }
        ev.accepted = true
    }
}
