import QtQuick
import QtQuick.Controls.Basic

Button {
    id: button

    property string glyph
    property string label
    property string face
    property bool active: false
    property real level: 1
    property bool charging: false
    property bool muted: false
    property color ink: "#f5f7fb"
    property color labelColor: "#f5f5f5"
    property bool clickable: true
    // Matches RiceTheme.radiusSmall; the bar draws before a theme is in scope.
    property int cornerRadius: 6

    implicitWidth: Math.max(24, contents.implicitWidth + 10)
    implicitHeight: 26
    padding: 0
    hoverEnabled: clickable
    focusPolicy: clickable ? Qt.TabFocus : Qt.NoFocus

    HoverHandler {
        enabled: button.clickable
        cursorShape: Qt.PointingHandCursor
    }

    background: Rectangle {
        radius: button.cornerRadius
        color: button.clickable && (button.active || button.hovered || button.visualFocus) ? "#18ffffff" : "transparent"
    }

    contentItem: Item {
        Row {
            id: contents
            anchors.centerIn: parent
            spacing: 4

            RiceBarGlyph {
                anchors.verticalCenter: parent.verticalCenter
                width: implicitWidth
                height: implicitHeight
                glyph: button.glyph
                level: button.level
                charging: button.charging
                muted: button.muted
                ink: button.ink
            }

            Text {
                visible: button.label.length > 0
                anchors.verticalCenter: parent.verticalCenter
                text: button.label
                color: button.labelColor
                font.family: button.face
                font.pixelSize: 12
            }
        }
    }
}
