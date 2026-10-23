// Test double for Purpose's AlternativesView: createJob() "runs" the target.
import QtQuick

Item {
    id: view
    property string pluginType
    property var inputData
    signal finished(var output, int error, string message)
    property int job: -1

    function createJob(index) { job = index; timer.start() }
    Timer {
        id: timer
        interval: 50
        onTriggered: {
            if (view.job === 2)
                view.finished({ "url": "https://i.imgur.com/abc.png", "files": view.inputData.urls.length }, 0, "")
            else if (view.job === 1)
                view.finished({}, 1, "No device connected")
            else
                view.finished({}, 0, "")
        }
    }
}
