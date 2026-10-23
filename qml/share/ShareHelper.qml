// Share helper: runs under the *system* Qt `qml` runtime (not inside Gallery) so it
// can load KDE's Purpose framework -- the same share targets Dolphin shows.
//
//   qml ShareHelper.qml -- list <mime> - <file urls...>        print targets, exit
//   qml ShareHelper.qml -- run  <mime> <pluginId> <file urls...> run one target
//
// Results are printed as "LGSHARE <json>" lines (see backend/share.py).
import QtQuick
import QtQuick.Controls
import org.kde.purpose as Purpose

ApplicationWindow {
    id: win
    width: 460
    height: 540
    visible: false
    title: qsTr("Share")

    property bool done: false
    readonly property var args: {
        const all = Qt.application.arguments
        const i = all.indexOf("--")
        return i >= 0 ? all.slice(i + 1) : []
    }
    readonly property string mode: args.length > 0 ? args[0] : "list"
    readonly property string mime: args.length > 1 ? args[1] : "image/*"
    readonly property string pluginId: args.length > 2 ? args[2] : "-"
    readonly property var urls: args.slice(3)
    readonly property var input: ({ "urls": win.urls, "mimeType": win.mime })

    function send(obj) { console.log("LGSHARE " + JSON.stringify(obj)) }
    function finish(code, delay) { exitTimer.code = code; exitTimer.interval = delay; exitTimer.start() }

    Timer { id: exitTimer; property int code: 0; onTriggered: Qt.exit(code) }

    Purpose.PurposeAlternativesModel {
        id: alts
        pluginType: "Export"
        inputData: win.input
    }

    // read the model rows through their role names
    Instantiator {
        id: rows
        model: alts
        delegate: QtObject {
            readonly property string pid: model.pluginId || ""
            readonly property string name: model.actionDisplay || model.display || ""
            readonly property string icon: model.iconName || ""
        }
    }

    function targets() {
        const out = []
        for (let i = 0; i < rows.count; ++i) {
            const row = rows.objectAt(i)
            if (row) out.push({ "id": row.pid, "name": row.name, "icon": row.icon, "index": i })
        }
        return out
    }

    function start() {
        if (mode === "list") {
            send({ "event": "targets", "targets": targets() })
            finish(0, 0)
            return
        }
        const list = targets()
        let index = -1
        for (let i = 0; i < list.length; ++i)
            if (list[i].id === pluginId) index = i
        if (index < 0) {
            send({ "event": "finished", "error": 1, "message": qsTr("This share option is not available") })
            finish(1, 0)
            return
        }
        if (typeof view.createJob === "function") {
            view.createJob(index)
            showTimer.start()      // only appears if the target asks for something
        } else {
            win.visible = true     // older Purpose: let the user pick in the list
        }
    }

    // Targets that need input (device, account, ...) keep running: show their UI.
    Timer {
        id: showTimer
        interval: 450
        onTriggered: if (!win.done) { win.visible = true; win.requestActivate() }
    }

    Purpose.AlternativesView {
        id: view
        anchors.fill: parent
        anchors.margins: 12
        pluginType: "Export"
        inputData: win.input
        onFinished: (output, error, message) => {
            win.done = true
            win.send({ "event": "finished", "output": output, "error": error, "message": message })
            win.visible = false
            win.finish(error ? 1 : 0, 400)
        }
    }

    onClosing: {
        if (!done) {
            send({ "event": "cancelled" })
            finish(2, 0)
        }
    }

    Component.onCompleted: Qt.callLater(start)
}
