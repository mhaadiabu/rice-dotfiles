import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Networking

// Top bar plus the Wi-Fi and sound popovers.
// Palette follows T3 Code: neutral near-black, hairline borders, white as the only accent.
ShellRoot {
PanelWindow {
    id: root

    Component.onCompleted: {
        statusReader.running = true;
        niriEvents.running = true;
        systemStatsReader.running = true;
    }

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 38
    color: "transparent"

    // Palette
    readonly property color bg: "transparent"
    readonly property color panel: "#f9161616"
    readonly property color hover: "#18ffffff"
    readonly property color line: "#262626"
    readonly property color fgStrong: "#f5f5f5"
    readonly property color fg: "#d4d4d4"
    readonly property color fgMuted: "#8a8a8a"
    readonly property color accent: "#6ea8fe"
    readonly property string face: "Aptos Narrow"

    readonly property UPowerDevice battery: UPower.displayDevice
    readonly property bool batteryPresent: battery.ready && battery.isPresent
    readonly property int batteryPercent: Math.round(battery.percentage * 100)
    readonly property bool batteryLow: batteryPresent && batteryPercent <= 20
    readonly property bool batteryCharging: batteryPresent && (
        battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.PendingCharge
    )
    readonly property string batteryLevel: batteryPresent ? batteryPercent + "%" : "--"
    readonly property string batteryIcon: {
        if (batteryLow)
            return batteryCharging ? "battery-low-charging-red-symbolic.svg" : "battery-low-red-symbolic.svg";
        const level = batteryPercent >= 85 ? "full" : batteryPercent >= 55 ? "good" : batteryPercent >= 25 ? "medium" : "low";
        return "battery-" + level + (batteryCharging ? "-charging-symbolic.svg" : "-symbolic.svg");
    }
    readonly property bool wifiOn: Networking.wifiEnabled && Networking.wifiHardwareEnabled
    readonly property WifiDevice wifiDevice: Networking.devices.values.find(device => device.type === DeviceType.Wifi) ?? null
    readonly property bool wifiConnected: (wifiDevice?.networks.values.some(network => network.connected) ?? false)
    readonly property bool wifiActive: wifiOn && wifiConnected
    property string volumeLevel: "--"
    property bool muted: false
    property int workspaceIndex: 0
    property var niriWorkspaces: []
    property var workspaceIndices: []
    property string focusedTitle: "Desktop"
    property bool wifiMenuOpen: false
    property bool volumeMenuOpen: false
    property var audioOutputs: []
    property bool overviewOpen: false
    property int cpuPercent: 0
    property int memPercent: 0

    function focusWorkspace(id) {
        const focused = niriWorkspaces.find(workspace => workspace.id === id);
        if (!focused) return;
        workspaceIndex = focused.idx;
        const indices = niriWorkspaces
            .filter(workspace => workspace.output === focused.output)
            .map(workspace => workspace.idx)
            .sort((a, b) => a - b);
        if (indices.length !== workspaceIndices.length
            || indices.some((index, position) => index !== workspaceIndices[position])) {
            workspaceIndices = indices;
        }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#80000000" }
            GradientStop { position: 0.55; color: "#60000000" }
            GradientStop { position: 1; color: "transparent" }
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Row {
                spacing: 5
                anchors.verticalCenter: parent.verticalCenter
                Repeater {
                    model: root.workspaceIndices
                    Rectangle {
                        required property var modelData
                        width: modelData === root.workspaceIndex ? 18 : 5
                        height: 5
                        radius: 3
                        color: modelData === root.workspaceIndex ? "white" : "#b8ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }
                }
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7
                Text {
                    text: root.focusedTitle
                    width: Math.min(implicitWidth, 320)
                    elide: Text.ElideRight
                    color: "white"
                    font.family: root.face
                    font.pixelSize: 12
                }
            }
        }

        Button {
            id: clockButton
            anchors.centerIn: parent
            width: clockLabel.implicitWidth + 20
            height: 26
            padding: 10
            topPadding: 0
            bottomPadding: 0
            hoverEnabled: true
            Accessible.name: "Notification Center, " + Qt.formatDateTime(clock.date, "ddd MMM d, HH:mm")

            onClicked: {
                root.wifiMenuOpen = false;
                root.volumeMenuOpen = false;
                notificationCenter.toggle();
            }

            HoverHandler { cursorShape: Qt.PointingHandCursor }

            background: Rectangle {
                radius: 6
                color: notificationCenter.shown || clockButton.hovered || clockButton.down || clockButton.visualFocus ? root.hover : "transparent"
            }

            contentItem: Row {
                id: clockLabel
                spacing: 10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: root.fgStrong
                    font.family: root.face
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(clock.date, "ddd MMM d")
                    color: "#e6ffffff"
                    font.family: root.face
                    font.pixelSize: 12
                }
            }
        }

        RiceNotifications {
            id: notificationCenter
            bar: root
            trigger: clockButton
            today: clock.date
            panelColor: root.panel
            face: root.face
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            // Minimal system monitor chip (CPU & RAM)
            Rectangle {
                id: sysMonitorChip
                width: sysChipRow.implicitWidth + 18
                height: 26
                radius: 6
                color: sysMonitorArea.containsMouse ? root.hover : "transparent"

                Row {
                    id: sysChipRow
                    anchors.centerIn: parent
                    spacing: 5

                    Image {
                        source: Quickshell.shellPath("icons/mac-tahoe/activity-monitor-symbolic.svg")
                        sourceSize.width: 13
                        sourceSize.height: 13
                        width: 13
                        height: 13
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "CPU " + root.cpuPercent + "%"
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.cpuPercent > 80 ? "#ff6969" : root.fgStrong
                        font.family: root.face
                        font.pixelSize: 12
                    }

                    Rectangle {
                        width: 3
                        height: 3
                        radius: 1.5
                        color: "#80ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "RAM " + root.memPercent + "%"
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.memPercent > 85 ? "#ff6969" : root.fgStrong
                        font.family: root.face
                        font.pixelSize: 12
                    }
                }

                MouseArea {
                    id: sysMonitorArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        systemMonitorLauncher.running = true;
                    }
                }
            }

            Repeater {
                model: [
                    {
                        icon: root.wifiActive ? "network-wireless-on.svg" : "network-wireless-off.svg",
                        value: "",
                        dimmed: !root.wifiActive
                    },
                    {
                        icon: root.muted ? "audio-volume-muted-symbolic.svg" : Number(root.volumeLevel.replace("%", "")) < 35 ? "audio-volume-low-symbolic.svg" : "audio-volume-high-symbolic.svg",
                        value: root.muted ? "Muted" : root.volumeLevel,
                        dimmed: false
                    },
                    {
                        icon: root.batteryIcon,
                        value: root.batteryLevel,
                        dimmed: false
                    }
                ]
                Rectangle {
                    required property var modelData
                    required property int index
                    property bool active: (index === 0 && root.wifiMenuOpen) || (index === 1 && root.volumeMenuOpen)
                    width: modelData.value.length > 0 ? chip.implicitWidth + 20 : 28
                    height: 26
                    radius: 6
                    color: active || chipArea.containsMouse ? root.hover : "transparent"
                    Row {
                        id: chip
                        anchors.centerIn: parent
                        spacing: modelData.value.length > 0 ? 6 : 0
                        Image {
                            source: Quickshell.shellPath("icons/mac-tahoe/" + modelData.icon)
                            sourceSize.width: 14
                            sourceSize.height: 14
                            width: 14
                            height: 14
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: modelData.dimmed ? 0.45 : 1.0
                        }
                        Text {
                            visible: modelData.value.length > 0
                            text: modelData.value
                            anchors.verticalCenter: parent.verticalCenter
                            color: index === 2 && root.batteryLow ? "#ff6969" : root.fgStrong
                            font.family: root.face
                            font.pixelSize: 12
                        }
                    }
                    MouseArea {
                        id: chipArea
                        anchors.fill: parent
                        cursorShape: index < 2 ? Qt.PointingHandCursor : Qt.ArrowCursor
                        hoverEnabled: true
                        onClicked: {
                            if (index === 0) {
                                root.wifiMenuOpen = !root.wifiMenuOpen;
                                root.volumeMenuOpen = false;
                            } else if (index === 1) {
                                root.volumeMenuOpen = !root.volumeMenuOpen;
                                root.wifiMenuOpen = false;
                            }
                        }
                    }
                }
            }
        }

        RiceWifi {
            anchor.window: root
            anchor.rect.x: root.width - implicitWidth - 12
            anchor.rect.y: root.height + 4
            face: root.face
            panelColor: root.panel
            visible: root.wifiMenuOpen
            onVisibleChanged: if (!visible) root.wifiMenuOpen = false
        }

        // Sound popover
        PopupWindow {
            id: soundPopup
            anchor.window: root
            anchor.rect.x: root.width - 264
            anchor.rect.y: root.height + 4
            implicitWidth: 252
            implicitHeight: soundColumn.implicitHeight + 28
            visible: root.volumeMenuOpen
            grabFocus: true
            onVisibleChanged: {
                if (visible) audioOutputReader.running = true;
                else root.volumeMenuOpen = false;
            }
            color: "transparent"
            Rectangle {
                anchors.fill: parent
                radius: 18
                color: root.panel
                transformOrigin: Item.TopRight

                opacity: soundPopup.visible ? 1.0 : 0.0
                scale: soundPopup.visible ? 1.0 : 0.92
                transform: Translate {
                    y: soundPopup.visible ? 0 : -8
                    Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                }
                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Column {
                    id: soundColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 14
                    spacing: 12
                    Item {
                        width: parent.width
                        height: 22
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Sound"
                            color: root.fgStrong
                            font.family: root.face
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.muted ? "Muted" : root.volumeLevel
                            color: root.fgMuted
                            font.family: root.face
                            font.pixelSize: 12
                        }
                    }
                    Rectangle { width: parent.width; height: 1; color: root.line }
                    Row {
                        width: parent.width
                        spacing: 8
                        Slider {
                            id: volumeSlider
                            width: parent.width - 32
                            height: 24
                            from: 0
                            to: 1
                            value: Number(root.volumeLevel.replace("%", "")) / 100
                            background: Rectangle {
                                x: volumeSlider.leftPadding
                                y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                                width: volumeSlider.availableWidth
                                height: 14
                                radius: 7
                                color: "#454545"
                                Rectangle {
                                    width: volumeSlider.visualPosition * parent.width
                                    height: parent.height
                                    radius: 7
                                    color: "#a8a8a8"
                                }
                            }
                            handle: Rectangle {
                                x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                                y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                                width: 16
                                height: 16
                                radius: 8
                                color: "white"
                            }
                            onMoved: {
                                root.volumeLevel = Math.round(value * 100) + "%";
                                volumeControl.exec(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", value.toFixed(2)]);
                            }
                        }
                        Rectangle {
                            width: 24
                            height: 24
                            radius: 6
                            color: muteArea.containsMouse ? root.hover : "transparent"
                            Image {
                                anchors.centerIn: parent
                                width: 16
                                height: 16
                                sourceSize.width: 16
                                sourceSize.height: 16
                                source: Quickshell.shellPath("icons/mac-tahoe/" + (root.muted ? "audio-volume-muted-symbolic.svg" : Number(root.volumeLevel.replace("%", "")) < 35 ? "audio-volume-low-symbolic.svg" : "audio-volume-high-symbolic.svg"))
                            }
                            MouseArea {
                                id: muteArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.muted = !root.muted;
                                    volumeControl.exec(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", root.muted ? "1" : "0"]);
                                }
                            }
                        }
                    }
                    Text {
                        text: "Output"
                        color: root.fgMuted
                        font.family: root.face
                        font.pixelSize: 11
                    }
                    Column {
                        width: parent.width
                        spacing: 2
                        Repeater {
                            model: root.audioOutputs
                            Rectangle {
                                required property var modelData
                                width: parent.width
                                height: 30
                                radius: 6
                                color: outputArea.containsMouse || modelData.active ? root.hover : "transparent"
                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 9
                                    anchors.right: parent.right
                                    anchors.rightMargin: 9
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.name
                                    elide: Text.ElideRight
                                    color: root.fgStrong
                                    font.family: root.face
                                    font.pixelSize: 12
                                }
                                MouseArea {
                                    id: outputArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        audioOutputControl.command = ["wpctl", "set-default", String(modelData.id)];
                                        audioOutputControl.running = true;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: clock
        property date date: new Date()
        interval: 1000
        running: true
        repeat: true
        onTriggered: date = new Date()
    }

    // Reads volume and mute state as "volume|muted".
    Process {
        id: statusReader
        command: ["sh", "-c", "vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null); volume=$(printf '%s' \"$vol\" | awk '{printf \"%d%%\", $2 * 100}'); muted=0; case \"$vol\" in *MUTED*) muted=1;; esac; printf '%s|%s' \"${volume:---}\" \"$muted\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const values = text.trim().split("|");
                if (values.length === 2) {
                    root.volumeLevel = values[0];
                    root.muted = values[1] === "1";
                }
            }
        }
        onExited: refreshTimer.restart()
    }

    Process { id: volumeControl }
    Process {
        id: audioOutputControl
        onExited: audioOutputReader.running = true
    }
    Process {
        id: audioOutputReader
        command: ["python3", Quickshell.shellPath("audio-outputs.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.audioOutputs = JSON.parse(text); }
                catch (error) { console.warn("Could not read audio outputs:", error); }
            }
        }
    }
    Timer {
        id: refreshTimer
        interval: 10000
        running: true
        repeat: true
        onTriggered: if (!statusReader.running) statusReader.running = true
    }

    Process {
        id: systemStatsReader
        command: ["python3", "-u", Quickshell.shellPath("system-stats.py")]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const stats = JSON.parse(data);
                    if (stats.cpu !== undefined) root.cpuPercent = stats.cpu;
                    if (stats.mem !== undefined) root.memPercent = stats.mem;
                } catch (error) {}
            }
        }
    }

    Process {
        id: systemMonitorLauncher
        command: ["niri", "msg", "action", "spawn", "--", "rice-system-monitor"]
    }

    Process {
        id: niriEvents
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const event = JSON.parse(data);
                    if (event.WorkspacesChanged) {
                        root.niriWorkspaces = event.WorkspacesChanged.workspaces;
                        root.focusWorkspace(root.niriWorkspaces.find(workspace => workspace.is_focused)?.id);
                    } else if (event.WorkspaceActivated?.focused) {
                        root.focusWorkspace(event.WorkspaceActivated.id);
                    }
                    dock.applyWindowEvent(event);
                    if (event.OverviewOpenedOrClosed) {
                        root.overviewOpen = event.OverviewOpenedOrClosed.is_open;
                    }
                } catch (error) {
                    console.warn("Could not read Niri event:", error);
                }
            }
        }
        onRunningChanged: if (!running) running = true
    }

    IpcHandler {
        target: "notifications"
        function toggle(): void {
            root.wifiMenuOpen = false;
            root.volumeMenuOpen = false;
            notificationCenter.toggle();
        }
    }

}

RiceDock {
    id: dock
    overviewOpen: root.overviewOpen
    labelFont: root.face
    pinnedApps: dockPins.items
    onPinRequested: (appKey, desktopId, name) => {
        const existing = dockPins.items.find(pin => pin.appId.toLowerCase() === appKey);
        if (!existing && !desktopId) return;
        const pins = existing
            ? dockPins.items.filter(pin => pin !== existing)
            : dockPins.items.concat({ appId: desktopId, desktopId, name, icon: "" });
        dockPins.setText(JSON.stringify(pins, null, 2) + "\n");
        dockPins.items = pins;
    }
    onFocusedTitleChanged: root.focusedTitle = focusedTitle
}

FileView {
    id: dockPins
    path: Quickshell.shellPath("dock-pins.json")
    preload: true
    watchChanges: true
    atomicWrites: true
    blockWrites: true
    property var items: []
    onFileChanged: reload()
    onLoaded: {
        try {
            const pins = JSON.parse(text());
            if (Array.isArray(pins)) items = pins;
        } catch (error) {
            console.warn("Could not read dock pins:", error);
        }
    }
}

RiceUtilities {
    id: utilities
    face: root.face
    panelColor: root.panel
}

RiceSpotlight {
    utilities: utilities
    windows: dock.windows
    face: root.face
}

}
