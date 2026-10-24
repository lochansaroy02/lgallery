pragma Singleton
import QtQuick

// All colours, radii, spacing, fonts and motion values live here.
QtObject {
    property bool dark: false
    // "neutral": pure black & white, the accent only on highlights (One UI)
    // "tinted":  Material You, every surface takes a tone of the accent's hue
    property string colorStyle: "neutral"
    readonly property bool tinted: colorStyle === "tinted"

    // ---- the seed colour -------------------------------------------------------
    // set from Settings > Appearance > Accent colour (or KDE's / Windows' accent colour)
    readonly property color defaultAccent: "#3E91FF"
    property color seedColor: defaultAccent
    readonly property real seedHue: Math.max(0, seedColor.hslHue)
    readonly property real seedSat: seedColor.hslSaturation
    // grey seeds (Graphite) give grey palettes instead of an arbitrary red tint
    readonly property real tint: seedSat < 0.08 ? 0 : Math.min(1, seedSat * 1.4)
    // a tone of the seed's hue: chroma 0..1 (scaled by how colourful the seed is), lightness 0..1
    function tone(chroma, lightness, alpha) {
        return Qt.hsla(seedHue, Math.min(1, chroma * tint), lightness, alpha === undefined ? 1 : alpha)
    }

    // ---- colour roles -------------------------------------------------------------
    readonly property color bg: !tinted ? (dark ? "#000000" : "#F6F6F6")
                                        : (dark ? tone(0.20, 0.065) : tone(0.42, 0.965))
    readonly property color surface: !tinted ? (dark ? "#1C1C1E" : "#FFFFFF")
                                             : (dark ? tone(0.18, 0.115) : tone(0.60, 0.99))
    readonly property color surfaceHigh: !tinted ? (dark ? "#2C2C2E" : "#EEEEF0")
                                                 : (dark ? tone(0.16, 0.17) : tone(0.32, 0.915))
    readonly property color text: !tinted ? (dark ? "#F5F5F7" : "#111114")
                                          : (dark ? tone(0.30, 0.91) : tone(0.28, 0.10))
    readonly property color textSecondary: !tinted ? (dark ? "#98989F" : "#6E6E76")
                                                   : (dark ? tone(0.14, 0.70) : tone(0.14, 0.40))
    // Material You: a deeper tone of the seed in light mode, a soft pastel one in dark mode
    readonly property color accent: !tinted ? seedColor
        : Qt.hsla(seedHue, seedSat < 0.08 ? seedSat : Math.max(0.5, Math.min(0.9, seedSat)),
                  dark ? 0.78 : 0.42, 1)
    readonly property real accentLuma: 0.2126 * accent.r + 0.7152 * accent.g + 0.0722 * accent.b
    readonly property color accentText: tinted ? (dark ? tone(0.55, 0.16) : "#FFFFFF")
                                               : (accentLuma > 0.62 ? "#111114" : "#FFFFFF")
    readonly property color accentSoft: !tinted ? Qt.rgba(accent.r, accent.g, accent.b, dark ? 0.24 : 0.14)
                                                : (dark ? tone(0.38, 0.26) : tone(0.70, 0.89))
    // choices offered in Settings and View > Accent Colour
    readonly property var accentPalette: [
        { name: qsTr("One UI Blue"), color: "#3e91ff" },
        { name: qsTr("Indigo"), color: "#5b5fef" },
        { name: qsTr("Purple"), color: "#9b5de5" },
        { name: qsTr("Pink"), color: "#f2559a" },
        { name: qsTr("Red"), color: "#e5484d" },
        { name: qsTr("Orange"), color: "#f97316" },
        { name: qsTr("Amber"), color: "#f5a524" },
        { name: qsTr("Green"), color: "#22a861" },
        { name: qsTr("Teal"), color: "#14b8a6" },
        { name: qsTr("Sky"), color: "#0ea5e9" },
        { name: qsTr("Brown"), color: "#a47551" },
        { name: qsTr("Graphite"), color: "#6b7280" }
    ]
    readonly property color danger: dark ? "#FF5A5A" : "#E5393B"
    readonly property color placeholder: !tinted ? (dark ? "#161618" : "#E4E4E7")
                                                 : (dark ? tone(0.16, 0.10) : tone(0.28, 0.89))
    readonly property color hover: !tinted ? (dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.05))
                                           : Qt.rgba(accent.r, accent.g, accent.b, dark ? 0.10 : 0.08)
    readonly property color pressed: !tinted ? (dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.09))
                                             : Qt.rgba(accent.r, accent.g, accent.b, dark ? 0.18 : 0.14)
    readonly property color divider: !tinted ? (dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.06))
                                             : (dark ? tone(0.20, 0.80, 0.10) : tone(0.40, 0.20, 0.08))
    readonly property color scrim: Qt.rgba(0, 0, 0, dark ? 0.6 : 0.4)
    readonly property color navBg: !tinted ? (dark ? Qt.rgba(0.16, 0.16, 0.17, 0.94) : Qt.rgba(1, 1, 1, 0.96))
                                           : (dark ? tone(0.20, 0.14, 0.95) : tone(0.55, 0.945, 0.97))
    readonly property color shadow: dark ? Qt.rgba(0, 0, 0, 0.6) : Qt.rgba(0, 0, 0, 0.16)
    readonly property color toastBg: !tinted ? (dark ? "#3A3A3C" : "#2B2B2E")
                                             : (dark ? tone(0.18, 0.25) : tone(0.25, 0.20))
    // switch track when off
    readonly property color switchOff: !tinted ? (dark ? "#48484A" : "#C9C9CE")
                                               : (dark ? tone(0.14, 0.32) : tone(0.20, 0.78))
    readonly property color viewerBar: Qt.rgba(0, 0, 0, 0.45)

    // ---- shape ------------------------------------------------------------
    readonly property int radiusS: 12
    readonly property int radiusM: 18
    readonly property int radiusL: 26
    readonly property int radiusXL: 32
    readonly property int thumbRadius: 0          // One UI keeps grid thumbnails square
    readonly property int selectedThumbRadius: 10 // ...but rounds them while selected
    readonly property int gridGap: 2

    // ---- spacing ------------------------------------------------------------
    readonly property int s1: 4
    readonly property int s2: 8
    readonly property int s3: 12
    readonly property int s4: 16
    readonly property int s5: 24
    readonly property int s6: 32
    readonly property int pageMargin: 20
    readonly property int barHeight: 60
    readonly property int sectionHeight: 46
    readonly property int navHeight: 64

    // ---- type -------------------------------------------------------------------
    readonly property string fontFamily: Qt.application.font.family
    readonly property int fontHuge: 38
    readonly property int fontDisplay: 44    // One UI page title in the expanded header
    readonly property int fontTitle: 20
    readonly property int fontLarge: 17
    readonly property int fontBody: 15
    readonly property int fontSmall: 13
    readonly property int fontTiny: 11

    // ---- motion -------------------------------------------------------------------
    readonly property int durFast: 150
    readonly property int durNormal: 230
    readonly property int durSlow: 300
    readonly property int easing: Easing.OutCubic
}
