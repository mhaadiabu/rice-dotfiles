import QtQuick

Rectangle {
    id: surface

    required property bool motionEnabled
    property int revealOrigin: Item.TopRight
    transformOrigin: revealOrigin

    function reveal() {
        entry.stop();
        const animate = visible && motionEnabled;
        opacity = animate ? 0 : 1;
        scale = animate ? 0.97 : 1;
        if (animate) entry.start();
    }

    onVisibleChanged: reveal()
    onMotionEnabledChanged: if (!motionEnabled) reveal()

    ParallelAnimation {
        id: entry
        NumberAnimation {
            target: surface
            property: "opacity"
            to: 1
            duration: 140
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: surface
            property: "scale"
            to: 1
            duration: 160
            easing.type: Easing.OutCubic
        }
    }
}
