// Test double for Purpose's AlternativesModel (same role names as the real one).
import QtQuick

ListModel {
    property string pluginType
    property var inputData
    ListElement { pluginId: "clipboardplugin"; display: "Clipboard"; actionDisplay: "Copy to Clipboard"; iconName: "edit-copy" }
    ListElement { pluginId: "kdeconnectplugin"; display: "KDE Connect"; actionDisplay: "Send to Device..."; iconName: "kdeconnect" }
    ListElement { pluginId: "imgurplugin"; display: "Imgur"; actionDisplay: "Upload Publicly to Imgur"; iconName: "edit-paste" }
}
