pragma Singleton
import QtQuick

// All colours, radii, spacing, fonts and motion values live here.
QtObject {
    property bool dark: false

    // ---- colour ---------------------------------------------------------
    readonly property color bg: dark ? "#000000" : "#F6F6F6"
    readonly property color surface: dark ? "#1C1C1E" : "#FFFFFF"
    readonly property color surfaceHigh: dark ? "#2C2C2E" : "#EEEEF0"
    readonly property color text: dark ? "#F5F5F7" : "#111114"
    readonly property color textSecondary: dark ? "#98989F" : "#6E6E76"
    readonly property color accent: "#3E91FF"
    readonly property color accentText: "#FFFFFF"
    readonly property color accentSoft: dark ? Qt.rgba(0.243, 0.569, 1.0, 0.22) : Qt.rgba(0.243, 0.569, 1.0, 0.13)
    readonly property color danger: dark ? "#FF5A5A" : "#E5393B"
    readonly property color placeholder: dark ? "#161618" : "#E4E4E7"
    readonly property color hover: dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.05)
    readonly property color pressed: dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.09)
    readonly property color divider: dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.06)
    readonly property color scrim: Qt.rgba(0, 0, 0, dark ? 0.6 : 0.4)
    readonly property color navBg: dark ? Qt.rgba(0.16, 0.16, 0.17, 0.94) : Qt.rgba(1, 1, 1, 0.96)
    readonly property color shadow: dark ? Qt.rgba(0, 0, 0, 0.6) : Qt.rgba(0, 0, 0, 0.16)
    readonly property color toastBg: dark ? "#3A3A3C" : "#2B2B2E"
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
