import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import Quickshell.Networking

// Top bar, desktop popovers and dock.
ShellRoot {
PanelWindow {
    id: root

    Component.onCompleted: {
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
    readonly property WifiDevice wifiDevice: Networking.devices.values.find(device => device.type === DeviceType.Wifi) ?? null
    readonly property WifiNetwork connectedWifi: wifiDevice?.networks.values.find(network => network.connected) ?? null
    readonly property PwNodeAudio audio: Pipewire.defaultAudioSink?.audio ?? null
    property string settingsMenu: ""
    RiceTheme { id: appearanceTheme }
    PwObjectTracker { objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : [] }

    function openSettings(menu) {
        settingsMenu = settingsMenu === menu ? "" : menu;
    }

    PersistentProperties {
        id: preferences
        property bool dnd: false
    }
    property int workspaceIndex: 0
    property var niriWorkspaces: []
    property var workspaceIndices: []
    property string focusedTitle: "Desktop"
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

            onClicked: root.openSettings("notifications")

            HoverHandler { cursorShape: Qt.PointingHandCursor }

            background: Rectangle {
                radius: appearanceTheme.radiusSmall
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


        Row {
            anchors.right: parent.right
            anchors.rightMargin: appearanceTheme.popoverSide
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            // Minimal system monitor chip (CPU & RAM)
            Rectangle {
                id: sysMonitorChip
                width: sysChipRow.implicitWidth + 10
                height: 26
                radius: appearanceTheme.radiusSmall
                color: sysMonitorArea.containsMouse ? root.hover : "transparent"

                Row {
                    id: sysChipRow
                    anchors.centerIn: parent
                    spacing: 5

                    RiceBarGlyph {
                        glyph: "activity"
                        width: implicitWidth
                        height: implicitHeight
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

            RiceStatusButton {
                visible: controls.recording
                glyph: "record"
                ink: "#ff6268"
                enabled: !stopRecording.running
                Accessible.name: "Stop screen recording"
                onClicked: stopRecording.running = true
            }

            RiceStatusButton {
                visible: preferences.dnd
                glyph: "dnd"
                Accessible.name: "Do Not Disturb is on"
                onClicked: root.openSettings("controls")
            }

            RiceStatusButton {
                glyph: controls.hotspot ? "hotspot" : "wifi"
                level: root.connectedWifi?.signalStrength ?? 0
                active: root.settingsMenu === "wifi"
                Accessible.name: "Wi-Fi networks"
                onClicked: root.openSettings("wifi")
            }

            RiceStatusButton {
                glyph: "sound"
                level: root.audio?.volume ?? 0
                muted: !root.audio || root.audio.muted
                active: root.settingsMenu === "sound"
                Accessible.name: "Sound"
                onClicked: root.openSettings("sound")
            }

            RiceStatusButton {
                visible: root.batteryPresent
                glyph: "battery"
                level: root.batteryPercent / 100
                charging: root.batteryCharging
                ink: root.batteryLow ? "#ff6268" : "#f5f7fb"
                label: root.batteryLevel
                face: root.face
                labelColor: root.batteryLow ? "#ff6969" : root.fgStrong
                clickable: false
                Accessible.name: "Battery, " + label
            }

            RiceStatusButton {
                glyph: "controls"
                active: root.settingsMenu === "controls"
                Accessible.name: "Control Center"
                onClicked: root.openSettings("controls")
            }
        }

    }

    // One layer below the bar keeps its triggers outside the dismissal area.
    PanelWindow {
        id: menus
        screen: root.screen
        anchors { top: true; right: true; bottom: true; left: true }
        margins.top: root.height
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "rice-bar-menus"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        color: "transparent"
        visible: root.settingsMenu !== ""

        Item {
            id: menuLayer
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.settingsMenu = ""

            MouseArea {
                anchors.fill: parent
                onClicked: root.settingsMenu = ""
            }

            RiceWifi {
                x: parent.width - width - appearanceTheme.popoverSide
                y: appearanceTheme.popoverTop
                face: root.face
                theme: appearanceTheme
                motionEnabled: controls.motionEnabled
                visible: root.settingsMenu === "wifi"
            }

            RiceControlCenter {
                id: controls
                theme: appearanceTheme
                x: parent.width - width - appearanceTheme.popoverSide
                y: appearanceTheme.popoverTop
                face: root.face
                audio: root.audio
                wifiDevice: root.wifiDevice
                dnd: preferences.dnd
                onToggleDnd: preferences.dnd = !preferences.dnd
                onOpenWifi: root.settingsMenu = "wifi"
                soundOnly: root.settingsMenu === "sound"
                visible: root.settingsMenu === "controls" || root.settingsMenu === "sound"
            }
        }
    }

    RiceNotifications {
        id: notificationCenter
        bar: root
        host: menuLayer
        trigger: clockButton
        today: clock.date
        theme: appearanceTheme
        face: root.face
        motionEnabled: controls.motionEnabled
        shown: root.settingsMenu === "notifications"
        dnd: preferences.dnd
    }

    Timer {
        id: clock
        property date date: new Date()
        interval: 1000
        running: true
        repeat: true
        onTriggered: date = new Date()
    }

    Process {
        id: stopRecording
        command: ["sh", Quickshell.env("HOME") + "/.config/niri/screencast.sh", "--stop-only"]
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
                    // Let Flameshot capture the popover, then release the live overlay.
                    if (root.settingsMenu && event.WindowOpenedOrChanged?.window.app_id === "flameshot")
                        root.settingsMenu = "";
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
        target: "controlCenter"
        function toggle(): void { root.openSettings("controls"); }
        function toggleSound(): void { root.openSettings("sound"); }
    }

    IpcHandler {
        target: "notifications"
        function toggle(): void { root.openSettings("notifications"); }
    }

}

RiceDock {
    id: dock
    theme: appearanceTheme
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
    theme: appearanceTheme
    motionEnabled: controls.motionEnabled
}

RiceSpotlight {
    theme: appearanceTheme
    utilities: utilities
    windows: dock.windows
    face: root.face
}

}
