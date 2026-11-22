import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking

FocusScope {
    id: center

    required property string face
    required property var audio
    required property WifiDevice wifiDevice
    required property bool dnd
    property bool soundOnly: false
    required property RiceTheme theme
    property bool recording: false
    property int brightness: -1
    property int pendingBrightness: -1
    property var outputs: []
    property string feedback: ""
    readonly property BluetoothAdapter bluetooth: Bluetooth.defaultAdapter
    readonly property bool hotspot: wifiDevice?.mode === WifiDeviceMode.AccessPoint
    readonly property string networkName: wifiDevice?.networks.values.find(network => network.connected)?.name ?? ""
    signal toggleDnd()
    signal openWifi()

    implicitWidth: soundOnly ? 282 : 326
    implicitHeight: contents.implicitHeight + theme.panelPadding * 2
    property bool motionEnabled: true

    onVisibleChanged: {
        if (visible) {
            forceActiveFocus();
            feedback = "";
            status.running = true;
            if (soundOnly) readOutputs.running = true;
        }
    }
    onSoundOnlyChanged: {
        if (!visible) return;
        if (soundOnly) readOutputs.running = true;
        Qt.callLater(() => { if (center.visible) panel.reveal(); });
    }

    Process {
        id: status
        command: ["sh", Quickshell.shellPath("control-status.sh")]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const values = text.trim().split("|");
                if (values.length !== 4) return;
                if (!setBrightness.running && center.pendingBrightness < 0)
                    center.brightness = values[0] ? Number(values[0]) : -1;
                if (!appearance.running && values[1]) center.theme.dark = values[1] !== "'prefer-light'";
                center.recording = values[2] === "1";
                center.motionEnabled = values[3] !== "false";
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: status.running = true
    }

    function applyBrightness() {
        if (setBrightness.running || pendingBrightness < 0) return;
        setBrightness.command = ["brightnessctl", "-c", "backlight", "--min-value=1", "set", pendingBrightness + "%"];
        pendingBrightness = -1;
        setBrightness.running = true;
    }

    Process {
        id: setBrightness
        onExited: code => {
            if (code !== 0) center.feedback = "Couldn't change brightness";
            center.applyBrightness();
        }
    }

    Process {
        id: appearance
        onExited: code => {
            if (code !== 0) center.feedback = "Couldn't change appearance";
            status.running = true;
        }
    }

    Process {
        id: hotspotAction
        property string action
        onExited: code => {
            if (code !== 0) center.feedback = action === "copy" ? "Couldn't copy the password" : "Couldn't change hotspot";
            else if (action === "copy") center.feedback = "Password copied";
        }
    }

    function runHotspot(action) {
        if (hotspotAction.running || !wifiDevice) return;
        feedback = "";
        hotspotAction.action = action;
        hotspotAction.command = ["sh", Quickshell.shellPath("hotspot.sh"), wifiDevice.name, action];
        hotspotAction.running = true;
    }

    Process {
        id: readOutputs
        command: ["python3", Quickshell.shellPath("audio-outputs.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                try { center.outputs = JSON.parse(text); }
                catch (error) { console.warn("Could not read audio outputs:", error); }
            }
        }
    }

    Process {
        id: setOutput
        onExited: code => {
            if (code !== 0) center.feedback = "Couldn't switch audio output";
            readOutputs.running = true;
        }
    }

    component Glyph: Image {
        id: image
        property string glyph
        property color tint: center.theme.ink
        source: Quickshell.shellPath("icons/mac-tahoe/" + glyph + ".svg")
        sourceSize.width: 18
        sourceSize.height: 18
        layer.enabled: true
        layer.effect: MultiEffect {
            colorization: 1
            colorizationColor: image.tint
            brightness: 1
        }
    }

    component Tile: Button {
        id: tileButton
        property string glyph
        property string detail
        property bool active: false
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 56
        hoverEnabled: true
        padding: 10
        Accessible.name: text + ", " + detail

        HoverHandler { enabled: tileButton.enabled; cursorShape: Qt.PointingHandCursor }

        background: Rectangle {
            radius: center.theme.radiusCard
            color: tileButton.hovered ? center.theme.hover : center.theme.tile
            border.width: tileButton.visualFocus ? 1 : 0
            border.color: center.theme.accent
        }

        contentItem: RowLayout {
            spacing: 10
            opacity: tileButton.enabled ? 1 : 0.65

            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 16
                color: tileButton.active ? center.theme.accent : center.theme.hover
                Glyph {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    glyph: tileButton.glyph
                    tint: tileButton.active ? "white" : center.theme.ink
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    Layout.fillWidth: true
                    text: tileButton.text
                    elide: Text.ElideRight
                    color: center.theme.ink
                    font { family: center.face; pixelSize: 13; weight: Font.DemiBold }
                }
                Text {
                    Layout.fillWidth: true
                    text: tileButton.detail
                    elide: Text.ElideRight
                    color: center.theme.muted
                    font { family: center.face; pixelSize: 11 }
                }
            }
        }
    }

    component LevelSlider: Slider {
        id: slider
        Layout.fillWidth: true
        implicitHeight: 30
        padding: 3
        stepSize: 1
        to: 100
        hoverEnabled: true

        HoverHandler { cursorShape: Qt.PointingHandCursor }

        background: Rectangle {
            x: slider.leftPadding
            y: (slider.height - height) / 2
            width: slider.availableWidth
            height: 22
            radius: 11
            color: center.theme.hover
            border.width: slider.visualFocus ? 1 : 0
            border.color: center.theme.accent
            Rectangle {
                width: 19 + slider.visualPosition * Math.max(0, parent.width - 19)
                height: parent.height
                radius: parent.radius
                color: slider.enabled ? center.theme.accent : center.theme.tile
            }
        }

        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: (slider.height - height) / 2
            width: 19
            height: 19
            radius: height / 2
            color: slider.pressed ? "#dceaff" : "#ffffff"
            opacity: slider.enabled ? 1 : 0.35
        }
    }

    // Rounded group with the shared inner padding; children stack vertically.
    component Label: Text {
        color: center.theme.ink
        font { family: center.face; pixelSize: 13; weight: Font.DemiBold }
    }

    component TextButton: Button {
        id: textButton
        hoverEnabled: true
        font { family: center.face; pixelSize: 12 }
        palette.buttonText: center.theme.ink
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        background: Rectangle {
            radius: center.theme.radiusControl
            color: textButton.hovered || textButton.visualFocus ? center.theme.hover : center.theme.tile
        }
    }

    MouseArea { anchors.fill: parent }

    RiceMenuSurface {
        id: panel
        anchors.fill: parent
        motionEnabled: center.motionEnabled
        radius: center.theme.radiusPanel
        color: center.theme.surface
        border.color: center.theme.hover
        border.width: 1

        ColumnLayout {
            id: contents
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: center.theme.panelPadding }
            spacing: center.theme.gap

            RowLayout {
                visible: !center.soundOnly
                Label {
                    Layout.fillWidth: true
                    text: "Control Center"
                    font.pixelSize: 15
                }
                TextButton { text: "Wi-Fi networks"; onClicked: center.openWifi() }
            }

            GridLayout {
                Layout.fillWidth: true
                visible: !center.soundOnly
                columns: 2
                columnSpacing: 8
                rowSpacing: 8

                Tile {
                    text: "Wi-Fi"
                    glyph: "network-wireless-signal-excellent-symbolic"
                    enabled: center.wifiDevice !== null && Networking.wifiHardwareEnabled && !hotspotAction.running
                    active: Networking.wifiEnabled && Networking.wifiHardwareEnabled
                    detail: active ? center.networkName || "On" : enabled ? "Off" : "Unavailable"
                    onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                }
                Tile {
                    text: "Bluetooth"
                    glyph: "bluetooth-active-symbolic"
                    enabled: center.bluetooth !== null
                    active: center.bluetooth?.enabled ?? false
                    detail: !enabled ? "No adapter" : active ? "On" : "Off"
                    onClicked: center.bluetooth.enabled = !center.bluetooth.enabled
                }
                Tile {
                    text: "Hotspot"
                    glyph: "network-wireless-hotspot-symbolic"
                    enabled: center.wifiDevice !== null && Networking.wifiEnabled && Networking.wifiHardwareEnabled && !hotspotAction.running
                    active: center.hotspot
                    detail: hotspotAction.running && hotspotAction.action !== "copy" ? "Working…"
                        : active ? "On" : enabled ? "Off" : "Wi-Fi required"
                    onClicked: center.runHotspot(active ? "off" : "on")
                }
                Tile {
                    text: "Do Not Disturb"
                    glyph: "weather-clear-night-symbolic"
                    active: center.dnd
                    detail: active ? "On" : "Off"
                    onClicked: center.toggleDnd()
                }
                Tile {
                    Layout.columnSpan: 2
                    text: "Appearance"
                    glyph: "appearance-symbolic"
                    active: center.theme.dark
                    enabled: !appearance.running
                    detail: center.theme.dark ? "Dark" : "Light"
                    onClicked: {
                        appearance.command = ["gsettings", "set", "org.gnome.desktop.interface", "color-scheme",
                            center.theme.dark ? "prefer-light" : "prefer-dark"];
                        appearance.running = true;
                    }
                }
            }

            TextButton {
                visible: !center.soundOnly && center.hotspot
                enabled: !hotspotAction.running
                text: "Copy hotspot password"
                onClicked: center.runHotspot("copy")
            }

            RiceCard {
                theme: center.theme
                visible: !center.soundOnly
                Label { text: "Brightness" }
                RowLayout {
                    spacing: 8
                    Glyph {
                        Layout.preferredWidth: 17
                        Layout.preferredHeight: 17
                        glyph: "display-brightness-symbolic"
                    }
                    LevelSlider {
                        Accessible.name: "Brightness"
                        from: 1
                        enabled: center.brightness >= 0
                        value: Math.max(1, center.brightness)
                        onMoved: {
                            center.brightness = Math.round(value);
                            center.pendingBrightness = center.brightness;
                            center.applyBrightness();
                        }
                    }
                }
            }

            RiceCard {
                theme: center.theme
                RowLayout {
                    Label { Layout.fillWidth: true; text: "Sound" }
                    Text {
                        text: !center.audio ? "No output" : center.audio.muted ? "Muted" : Math.round(center.audio.volume * 100) + "%"
                        color: center.theme.muted
                        font { family: center.face; pixelSize: 12 }
                    }
                }
                RowLayout {
                    spacing: 8
                    Button {
                        id: muteButton
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 28
                        enabled: !!center.audio
                        hoverEnabled: true
                        Accessible.name: center.audio?.muted ? "Unmute" : "Mute"
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        background: Rectangle {
                            radius: center.theme.radiusControl
                            color: muteButton.hovered || muteButton.visualFocus ? center.theme.hover : "transparent"
                        }
                        RiceBarGlyph {
                            anchors.centerIn: parent
                            width: implicitWidth
                            height: implicitHeight
                            glyph: "sound"
                            ink: center.theme.ink
                            level: center.audio?.volume ?? 0
                            muted: !center.audio || center.audio.muted
                        }
                        onClicked: center.audio.muted = !center.audio.muted
                    }
                    LevelSlider {
                        Accessible.name: "Volume"
                        enabled: !!center.audio
                        value: (center.audio?.volume ?? 0) * 100
                        onMoved: if (center.audio) center.audio.volume = value / 100
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: center.soundOnly && center.outputs.length > 0
                spacing: 6
                Label { Layout.leftMargin: 2; text: "Output" }

                // Rows sit 4px inside the card, so their radius is the card's minus 4.
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: outputList.implicitHeight + 8
                    radius: center.theme.radiusCard
                    color: center.theme.tile

                    ColumnLayout {
                        id: outputList
                        anchors { fill: parent; margins: 4 }
                        spacing: 0

                        Repeater {
                            model: center.outputs
                            delegate: Button {
                                id: outputRow
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: 34
                                hoverEnabled: true
                                horizontalPadding: 10
                                enabled: !setOutput.running
                                Accessible.name: modelData.active ? modelData.name + ", current output" : modelData.name
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                                background: Rectangle {
                                    radius: center.theme.radiusControl
                                    color: outputRow.hovered || outputRow.visualFocus ? center.theme.hover : "transparent"
                                }
                                contentItem: RowLayout {
                                    spacing: 8
                                    Text {
                                        Layout.preferredWidth: 14
                                        text: outputRow.modelData.active ? "\u2713" : ""
                                        color: center.theme.accent
                                        horizontalAlignment: Text.AlignHCenter
                                        font { family: center.face; pixelSize: 13; weight: Font.DemiBold }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: outputRow.modelData.name
                                        color: center.theme.ink
                                        elide: Text.ElideRight
                                        font { family: center.face; pixelSize: 13 }
                                    }
                                }
                                onClicked: {
                                    setOutput.command = ["wpctl", "set-default", String(modelData.id)];
                                    setOutput.running = true;
                                }
                            }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: center.feedback.length > 0
                text: center.feedback
                color: center.theme.muted
                font { family: center.face; pixelSize: 12 }
            }
        }
    }
}
