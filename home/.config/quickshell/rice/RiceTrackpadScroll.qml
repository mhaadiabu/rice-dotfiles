import QtQuick

MouseArea {
    required property Flickable viewport

    Component.onCompleted: parent = viewport
    anchors.fill: parent
    z: 1
    acceptedButtons: Qt.NoButton
    scrollGestureEnabled: true

    onWheel: event => {
        const delta = event.pixelDelta.y;
        const range = viewport.contentHeight - viewport.height;
        event.accepted = Math.abs(delta) >= Math.abs(event.pixelDelta.x) && delta !== 0 && range > 0;
        if (!event.accepted) return;

        // Niri scales touchpad scrolling to 0.5. Give rice panels a lighter response.
        viewport.cancelFlick();
        const top = viewport.originY;
        const next = viewport.contentY - delta * 2.5;
        viewport.contentY = Math.max(top, Math.min(top + range, next));
    }
}
