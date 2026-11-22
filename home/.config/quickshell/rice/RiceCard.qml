import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// Rounded group inside a panel. Children stack vertically with the shared inner padding.
Pane {
    id: card

    required property RiceTheme theme

    Layout.fillWidth: true
    padding: 12

    background: Rectangle {
        radius: card.theme.radiusCard
        color: card.theme.tile
    }

    contentItem: ColumnLayout { spacing: 4 }
}
