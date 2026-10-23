import QtQuick
import QtMultimedia

// A video with its player. Kept in its own file and always created through a Loader, so
// Gallery still starts when the Qt Multimedia QML module (qt6-multimedia) is missing:
// the Loader then reports an error and the views offer "Open in default app" instead.
Item {
    id: surface
    property url source
    property bool muted: true
    property real volume: 1.0
    property bool loops: false
    property bool autoPlay: true
    property real playbackRate: 1.0
    property int startPosition: 0          // ms, applied once the media is loaded
    property int fillMode: VideoOutput.PreserveAspectFit
    property bool frameShown: false        // the first frame is on screen
    readonly property bool playing: mp.playbackState === MediaPlayer.PlayingState
    readonly property bool ended: mp.mediaStatus === MediaPlayer.EndOfMedia
    readonly property bool loading: mp.mediaStatus === MediaPlayer.LoadingMedia
                                    || mp.mediaStatus === MediaPlayer.StalledMedia
                                    || mp.mediaStatus === MediaPlayer.BufferingMedia
    readonly property int position: mp.position
    readonly property int duration: mp.duration
    readonly property bool seekable: mp.seekable
    readonly property string errorString: mp.error !== MediaPlayer.NoError
                                          ? (mp.errorString || qsTr("This video can't be played")) : ""

    function play() {
        if (ended) mp.setPosition(0)
        mp.play()
    }
    function pause() { mp.pause() }
    function toggle() { playing ? pause() : play() }
    function stop() { mp.stop() }
    function seek(ms) {
        var d = mp.duration
        mp.setPosition(Math.max(0, d > 0 ? Math.min(ms, d - 1) : ms))
    }

    property bool _started: false
    function _start() {
        if (_started || source.toString() === "") return
        _started = true
        if (autoPlay) mp.play()
    }
    onSourceChanged: { frameShown = false; _started = false; Qt.callLater(_start) }
    Component.onCompleted: Qt.callLater(_start)

    MediaPlayer {
        id: mp
        source: surface.source
        videoOutput: output
        audioOutput: AudioOutput {
            muted: surface.muted
            volume: surface.volume
        }
        loops: surface.loops ? MediaPlayer.Infinite : 1
        playbackRate: surface.playbackRate
        property bool positioned: false
        onSourceChanged: positioned = false
        onMediaStatusChanged: {
            if (!positioned && surface.startPosition > 0
                    && (mediaStatus === MediaPlayer.LoadedMedia || mediaStatus === MediaPlayer.BufferedMedia)) {
                positioned = true
                if (seekable) setPosition(surface.startPosition)
            }
        }
    }

    VideoOutput {
        id: output
        anchors.fill: parent
        fillMode: surface.fillMode
    }
    Connections {
        target: output.videoSink
        function onVideoFrameChanged() { if (!surface.frameShown) surface.frameShown = true }
    }
}
