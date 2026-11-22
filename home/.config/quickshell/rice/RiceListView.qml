import QtQuick

ListView {
    id: list
    boundsBehavior: Flickable.StopAtBounds
    acceptedButtons: Qt.NoButton
    flickableDirection: Flickable.VerticalFlick

    RiceTrackpadScroll { viewport: list }
}
