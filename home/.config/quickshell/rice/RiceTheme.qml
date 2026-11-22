import QtQuick

// Colors plus the shared geometry scale. Every surface takes its corner radius
// from here, with tighter corners as you move from panels to cards and rows.
QtObject {
    property bool dark: true

    // Corner radii. Pills use height / 2 instead.
    readonly property int radiusPanel: 24
    readonly property int radiusCard: 14
    readonly property int radiusControl: 9
    readonly property int radiusSmall: 6

    // Distance from a panel edge to its content, and between sibling blocks.
    readonly property int panelPadding: 14
    readonly property int gap: 10

    // Distance from the screen edge and the bar to a popover.
    readonly property int popoverSide: 8
    readonly property int popoverTop: 6

    readonly property color surface: dark ? "#fb22252a" : "#fbf4f5f8"
    readonly property color card: dark ? "#2c2e33" : "#e7ebf1"
    readonly property color tile: dark ? "#16ffffff" : "#0e192943"
    readonly property color hover: dark ? "#25ffffff" : "#1d192943"
    readonly property color selected: dark ? "#32ffffff" : "#29264877"
    readonly property color line: dark ? "#28ffffff" : "#29253348"
    readonly property color outline: dark ? "#697481" : "#838e9e"
    readonly property color ink: dark ? "#f5f7fa" : "#17202d"
    readonly property color secondary: dark ? "#d5dbe4" : "#394656"
    readonly property color muted: dark ? "#b2bbc7" : "#515c6b"
    readonly property color accent: dark ? "#297be2" : "#1765c8"
    readonly property color inverseInk: dark ? "#17202d" : "#ffffff"
    readonly property color error: dark ? "#ff9d95" : "#a52b24"
    readonly property color scrim: dark ? "#60000000" : "#36222d40"
    readonly property color dock: dark ? "#d01c1d21" : "#dfedf0f5"
}
