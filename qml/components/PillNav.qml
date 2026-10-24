import QtQuick
import QtQuick.Effects
import ".."

// Floating pill-shaped bottom navigation with a sliding rounded indicator.
// glass: "solid" (opaque pill), "frosted" or "clear" Liquid Glass. The glass shows
// `backdrop` (the page under the bar; it must not contain the bar) through a shader
// that blurs, tints and bends it at the rim (shaders/liquidglass.frag).
Item {
    id: nav
    property int currentIndex: 0
    property var items: [
        { label: qsTr("Pictures"), icon: "pictures" },
        { label: qsTr("Videos"), icon: "video" },
        { label: qsTr("Albums"), icon: "albums" },
        { label: qsTr("Collections"), icon: "collections" },
        { label: qsTr("Folders"), icon: "folder" }
    ]
    signal selected(int index)

    property string glass: "solid"
    property Item backdrop: null
    readonly property bool frosted: glass === "frosted"
    // shaders need the GPU renderer; the software one (and missing shader files) fall back to solid
    readonly property bool glassy: glass !== "solid" && backdrop !== null
                                   && GraphicsInfo.api !== GraphicsInfo.Software
    readonly property real glassPad: 24

    property real maxWidth: 100000      // narrow windows: the items shrink to fit
    readonly property real itemWidth: Math.max(64, Math.min(100, (maxWidth - 12) / items.length))
    implicitWidth: items.length * itemWidth + 12
    implicitHeight: Theme.navHeight

    MultiEffect {
        source: pill
        anchors.fill: pill
        shadowEnabled: true
        shadowColor: Theme.shadow
        shadowBlur: 1.0
        shadowVerticalOffset: 4
        autoPaddingEnabled: true
    }
    // ---- glass: what is behind the bar, blurred, then refracted and tinted by the shader ----
    ShaderEffectSource {
        id: behind
        visible: false
        live: true
        sourceItem: nav.glassy ? nav.backdrop : null
        // the bar's rectangle in the backdrop (same parent, so the same coordinates) plus spare
        sourceRect: Qt.rect(nav.x - nav.glassPad, nav.y - nav.glassPad,
                            nav.width + 2 * nav.glassPad, nav.height + 2 * nav.glassPad)
        width: sourceRect.width
        height: sourceRect.height
    }
    MultiEffect {
        id: blurred
        width: behind.width
        height: behind.height
        visible: nav.glassy
        source: behind
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: nav.frosted ? 48 : 16
        blur: nav.frosted ? 1.0 : 0.3
        saturation: nav.frosted ? 0.25 : 0.15
        brightness: Theme.dark ? -0.04 : 0.02
    }
    ShaderEffectSource {
        id: blurredTexture
        visible: false
        live: true
        hideSource: true
        sourceItem: nav.glassy ? blurred : null
    }

    Rectangle {
        id: pill
        anchors.fill: parent
        radius: height / 2
        color: Theme.navBg

        ShaderEffect {
            id: glassEffect
            anchors.fill: parent
            visible: nav.glassy && status !== ShaderEffect.Error
            property var source: blurredTexture
            property size barSize: Qt.size(width, height)
            property real barRadius: height / 2
            property real pad: nav.glassPad
            property real edge: nav.frosted ? 14 : 16
            property real refraction: nav.frosted ? 0.55 : 0.85
            property real dispersion: nav.frosted ? 0.6 : 1.8
            property real highlight: nav.frosted ? (Theme.dark ? 0.10 : 0.20) : (Theme.dark ? 0.16 : 0.32)
            // frosted: a milky layer in the bar's own colour; clear: barely tinted
            property vector4d tint: nav.frosted
                ? Qt.vector4d(Theme.navBg.r, Theme.navBg.g, Theme.navBg.b, Theme.dark ? 0.55 : 0.50)
                : (Theme.dark ? Qt.vector4d(0, 0, 0, 0.34) : Qt.vector4d(1, 1, 1, 0.26))
            fragmentShader: "../shaders/liquidglass.frag.qsb"
        }

        Rectangle {
            id: indicator
            y: 6
            height: parent.height - 12
            width: nav.itemWidth
            radius: height / 2
            color: Theme.accentSoft
            x: 6 + nav.currentIndex * nav.itemWidth
            Behavior on x { NumberAnimation { duration: Theme.durSlow; easing.type: Theme.easing } }
        }
        Row {
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
                model: nav.items
                delegate: Item {
                    required property var modelData
                    required property int index
                    width: nav.itemWidth
                    height: nav.height - 12
                    readonly property bool active: index === nav.currentIndex
                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: modelData.icon
                            size: 21
                            color: active ? Theme.accent : Theme.textSecondary
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.label
                            font.pixelSize: Theme.fontTiny + 1
                            font.weight: active ? Font.Bold : Font.Medium
                            color: active ? Theme.accent : Theme.textSecondary
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: nav.selected(index)
                    }
                }
            }
        }
    }
}
