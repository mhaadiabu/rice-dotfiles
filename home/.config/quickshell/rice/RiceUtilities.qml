import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: panel
    required property string face
    required property RiceTheme theme
    required property bool motionEnabled
    property string mode: ""
    property var items: []
    property bool confirmPower: false
    property string pendingPower: ""
    readonly property var powerActions: [
        { name: "Lock Screen", key: "L", num: "1", icon: "system-lock-screen.svg", command: ["hyprlock"] },
        { name: "Sleep",       key: "S", num: "2", icon: "system-suspend.svg",     command: ["systemctl", "suspend"] },
        { name: "Log Out",     key: "E", num: "3", icon: "system-log-out.svg",     command: ["niri", "msg", "action", "quit", "--skip-confirmation"], confirm: true },
        { name: "Restart",     key: "R", num: "4", icon: "system-reboot.svg",      command: ["systemctl", "reboot"], confirm: true },
        { name: "Shut Down",   key: "P", num: "5", icon: "system-shutdown.svg",    command: ["systemctl", "poweroff"], confirm: true }
    ]

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "rice-utilities"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    color: "transparent"
    visible: mode !== ""

    function toggle(next) {
        if (mode === next) {
            mode = "";
            return;
        }
        if (next !== "clipboard" && next !== "wallpaper" && next !== "power") return;
        search.clear();
        pendingPower = "";
        confirmPower = false;
        items = [];
        mode = next;
        if (next !== "power") reader.running = true;
        Qt.callLater(() => next === "power" ? card.forceActiveFocus() : search.forceActiveFocus());
    }

    function activate(item) {
        if (!item) return;
        if (mode === "power" && item.confirm && pendingPower !== item.name) {
            pendingPower = item.name;
            confirmPower = true;
            return;
        }
        const command = mode === "power" ? item.command
            : mode === "wallpaper" ? ["rice-desktop", "set-wallpaper", item.location]
            : ["rice-desktop", "paste-history", item.id];
        mode = "";
        pendingPower = "";
        confirmPower = false;
        Quickshell.execDetached(command);
    }

    IpcHandler {
        target: "utilities"
        function toggle(mode: string): void { panel.toggle(mode); }
    }

    Process {
        id: reader
        property string requestedMode: ""
        onStarted: requestedMode = panel.mode
        command: panel.mode === "wallpaper" ? ["python3", Quickshell.shellPath("wallpapers.py")]
            : ["sh", "-c", "command -v cliphist >/dev/null && cliphist list"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (reader.requestedMode !== panel.mode) return;
                if (panel.mode === "wallpaper") {
                    try { panel.items = JSON.parse(text); }
                    catch (error) { console.warn("Could not read wallpapers:", error); }
                } else if (panel.mode === "clipboard") {
                    const history = [];
                    for (const line of text.split("\n")) {
                        const tab = line.indexOf("\t");
                        if (tab >= 0) history.push({ id: line.slice(0, tab), name: line.slice(tab + 1) });
                    }
                    panel.items = history;
                }
            }
        }
        onExited: if (panel.mode && panel.mode !== "power" && panel.mode !== requestedMode) running = true
    }

    Rectangle {
        anchors.fill: parent
        color: panel.theme.scrim
    }

    TapHandler {
        onTapped: if (!card.contains(card.mapFromItem(null, point.position))) {
            if (panel.confirmPower) {
                panel.pendingPower = "";
                panel.confirmPower = false;
            } else {
                panel.mode = "";
            }
        }
    }

    RiceMenuSurface {
        id: card
        motionEnabled: panel.motionEnabled
        revealOrigin: Item.Center
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, panel.mode === "power" ? 330 : 550)
        height: Math.min(parent.height - 52, body.implicitHeight + 28)
        color: panel.theme.surface
        radius: panel.theme.radiusPanel
        border.width: 1
        border.color: panel.theme.line
        clip: true

        Keys.onEscapePressed: {
            if (panel.confirmPower) {
                panel.pendingPower = "";
                panel.confirmPower = false;
            } else {
                panel.mode = "";
            }
        }

        Keys.onPressed: event => {
            if (panel.mode === "power" && !panel.confirmPower) {
                const keyText = event.text.toUpperCase();
                const matched = panel.powerActions.find(a => a.key === keyText || a.num === keyText);
                if (matched) {
                    panel.activate(matched);
                    event.accepted = true;
                    return;
                }
            } else if (panel.mode === "power" && panel.confirmPower) {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    const action = panel.powerActions.find(a => a.name === panel.pendingPower);
                    if (action) {
                        panel.mode = "";
                        panel.pendingPower = "";
                        panel.confirmPower = false;
                        Quickshell.execDetached(action.command);
                    }
                    event.accepted = true;
                    return;
                }
            }

            if (event.key === Qt.Key_Down) {
                list.incrementCurrentIndex();
                event.accepted = true;
            } else if (event.key === Qt.Key_Up) {
                list.decrementCurrentIndex();
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (list.currentIndex >= 0 && list.currentIndex < list.model.length) {
                    panel.activate(list.model[list.currentIndex]);
                }
                event.accepted = true;
            }
        }

        ColumnLayout {
            id: body
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Layout.bottomMargin: 2

                Text {
                    text: panel.mode === "power" ? (panel.confirmPower ? "Confirm " + panel.pendingPower : "Power")
                        : panel.mode === "wallpaper" ? "Wallpapers" : "Clipboard"
                    color: panel.theme.ink
                    font.family: panel.face
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }

                Rectangle {
                    visible: panel.mode === "power" && !panel.confirmPower
                    width: 36
                    height: 20
                    radius: panel.theme.radiusSmall
                    color: panel.theme.tile
                    border.width: 1
                    border.color: panel.theme.selected
                    Text {
                        anchors.centerIn: parent
                        text: "ESC"
                        color: panel.theme.muted
                        font.family: panel.face
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }
                }
            }

            TextField {
                id: search
                Layout.fillWidth: true
                visible: panel.mode !== "power"
                placeholderText: panel.mode === "wallpaper" ? "Find a wallpaper" : "Find in clipboard"
                color: panel.theme.ink
                placeholderTextColor: panel.theme.muted
                selectionColor: panel.theme.accent
                selectedTextColor: "#ffffff"
                font.family: panel.face
                font.pixelSize: 15
                padding: 9
                background: Rectangle { radius: panel.theme.radiusControl; color: panel.theme.hover }
                onTextChanged: list.currentIndex = 0
                Keys.onDownPressed: list.incrementCurrentIndex()
                Keys.onUpPressed: list.decrementCurrentIndex()
                Keys.onReturnPressed: panel.activate(list.model[list.currentIndex])
            }

            // Power Confirmation Box
            ColumnLayout {
                visible: panel.confirmPower
                Layout.fillWidth: true
                spacing: 14
                Layout.topMargin: 4
                Layout.bottomMargin: 4

                Text {
                    Layout.fillWidth: true
                    text: panel.pendingPower + " the computer now? Unsaved work may be lost."
                    color: panel.theme.muted
                    font.family: panel.face
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Button {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        text: "Cancel"
                        font.family: panel.face
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        background: Rectangle {
                            radius: panel.theme.radiusControl
                            color: parent.hovered ? panel.theme.hover : panel.theme.tile
                            border.width: 1
                            border.color: panel.theme.line
                        }
                        contentItem: Text {
                            text: parent.text
                            font: parent.font
                            color: panel.theme.ink
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: {
                            panel.pendingPower = "";
                            panel.confirmPower = false;
                        }
                    }

                    Button {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        text: panel.pendingPower
                        font.family: panel.face
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        background: Rectangle {
                            radius: panel.theme.radiusControl
                            color: parent.hovered ? "#e53935" : "#c62828"
                        }
                        contentItem: Text {
                            text: parent.text
                            font: parent.font
                            color: "#ffffff"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: {
                            const action = panel.powerActions.find(a => a.name === panel.pendingPower);
                            if (action) {
                                panel.mode = "";
                                panel.pendingPower = "";
                                panel.confirmPower = false;
                                Quickshell.execDetached(action.command);
                            }
                        }
                    }
                }
            }

            // Normal Options List
            RiceListView {
                id: list
                visible: !panel.confirmPower
                Layout.fillWidth: true
                Layout.fillHeight: true
                readonly property int rowHeight: panel.mode === "wallpaper" ? 70 : (panel.mode === "power" ? 44 : 38)
                implicitHeight: Math.min(350, Math.max(count, 1) * rowHeight)
                clip: true
                model: panel.mode === "power"
                    ? panel.powerActions
                    : panel.items.filter(item => item.name.toLowerCase().includes(search.text.trim().toLowerCase()))
                ScrollBar.vertical: ScrollBar {
                    palette.mid: panel.theme.outline
                    palette.dark: panel.theme.ink
                }
                delegate: ItemDelegate {
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: list.rowHeight
                    hoverEnabled: true
                    padding: 4
                    leftPadding: 8
                    rightPadding: 8
                    Accessible.name: modelData.name

                    background: Rectangle {
                        radius: panel.theme.radiusControl
                        color: parent.hovered || parent.visualFocus || ((search.activeFocus || card.activeFocus) && index === list.currentIndex)
                            ? panel.theme.selected : "transparent"
                        border.width: 1
                        border.color: parent.hovered ? panel.theme.line : "transparent"
                    }

                    contentItem: RowLayout {
                        spacing: 12

                        // Icon container for power actions
                        Rectangle {
                            visible: panel.mode === "power" && Boolean(modelData.icon)
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: panel.theme.radiusControl
                            color: panel.theme.tile
                            Image {
                                anchors.centerIn: parent
                                source: modelData.icon ? Quickshell.shellPath("icons/mac-tahoe/" + modelData.icon) : ""
                                layer.enabled: !panel.theme.dark
                                layer.effect: MultiEffect {
                                    colorization: 1
                                    colorizationColor: panel.theme.ink
                                    brightness: 1
                                }
                                sourceSize.width: 16
                                sourceSize.height: 16
                                width: 16
                                height: 16
                            }
                        }

                        // Wallpaper preview
                        Rectangle {
                            visible: Boolean(modelData.url)
                            Layout.preferredWidth: 82
                            Layout.preferredHeight: 52
                            radius: panel.theme.radiusSmall
                            color: panel.theme.card
                            clip: true
                            Image {
                                anchors.fill: parent
                                source: modelData.url || ""
                                sourceSize.width: 164
                                sourceSize.height: 104
                                asynchronous: true
                                fillMode: Image.PreserveAspectCrop
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.name
                            elide: Text.ElideRight
                            color: panel.theme.ink
                            font.family: panel.face
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }

                        // Hotkey badge (e.g. L, S, E, R, P)
                        Row {
                            visible: panel.mode === "power" && Boolean(modelData.key)
                            spacing: 4
                            Layout.alignment: Qt.AlignVCenter

                            Rectangle {
                                width: 22
                                height: 22
                                radius: panel.theme.radiusSmall
                                color: panel.theme.tile
                                border.width: 1
                                border.color: panel.theme.line
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.key || ""
                                    color: panel.theme.muted
                                    font.family: panel.face
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                    }

                    onClicked: panel.activate(modelData)
                }

                Text {
                    visible: list.count === 0 && panel.mode !== "power"
                    text: search.text ? "No matches" : panel.mode === "wallpaper" ? "No wallpapers found" : "Clipboard history is empty"
                    color: panel.theme.muted
                    anchors.centerIn: parent
                    font.family: panel.face
                    font.pixelSize: 14
                }
            }
        }
    }
}
