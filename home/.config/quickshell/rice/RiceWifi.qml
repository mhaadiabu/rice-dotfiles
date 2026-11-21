import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking

PopupWindow {
    id: wifi
    required property string face
    required property color panelColor

    readonly property WifiDevice adapter: Networking.devices.values.find(device => device.type === DeviceType.Wifi) ?? null
    readonly property bool radioOn: Networking.wifiEnabled && Networking.wifiHardwareEnabled
    readonly property var networks: adapter?.networks.values ?? []
    readonly property WifiNetwork connectedNetwork: networks.find(network => network.connected) ?? null
    property WifiNetwork selected: null
    property string phase: "idle"
    property string errorText: ""
    property bool usedPassword: false
    readonly property bool joining: phase === "joining"
    readonly property bool asksForPassword: phase === "password"

    implicitWidth: 302
    implicitHeight: contents.implicitHeight + 26
    grabFocus: true
    color: "transparent"

    function supportsPassword(network) {
        return [WifiSecurityType.WpaPsk, WifiSecurityType.Wpa2Psk, WifiSecurityType.Sae].includes(network.security);
    }

    function securityLabel(network) {
        if (network.security === WifiSecurityType.Open) return "Open network";
        if (network.security === WifiSecurityType.Owe) return "Enhanced Open";
        if (supportsPassword(network)) return "Password protected";
        if ([WifiSecurityType.WpaEap, WifiSecurityType.Wpa2Eap, WifiSecurityType.Wpa3SuiteB192].includes(network.security))
            return "Enterprise network";
        return "Secured network";
    }

    function reset() {
        deadline.stop();
        secret.clear();
        reveal.checked = false;
        errorText = "";
        usedPassword = false;
        phase = "idle";
        selected = null;
    }

    function choose(network) {
        selected = network;
        errorText = "";
        if (network.known || network.security === WifiSecurityType.Open || network.security === WifiSecurityType.Owe) {
            phase = "confirm";
        } else if (supportsPassword(network)) {
            phase = "password";
            Qt.callLater(() => { if (wifi.visible && wifi.asksForPassword) secret.forceActiveFocus(); });
        } else {
            phase = "unsupported";
        }
    }

    function join() {
        if (!selected || joining || selected.stateChanging) return;
        if (asksForPassword && !secret.length) return;
        usedPassword = asksForPassword;
        const password = asksForPassword ? secret.text : "";
        secret.clear();
        reveal.checked = false;
        errorText = "";
        phase = "joining";
        deadline.restart();
        if (password) selected.connectWithPsk(password);
        else selected.connect();
    }

    function fail(message, needsPassword) {
        deadline.stop();
        errorText = message;
        phase = needsPassword ? "password" : "confirm";
        if (needsPassword && visible) Qt.callLater(() => secret.forceActiveFocus());
    }

    onVisibleChanged: if (!visible && !joining) reset()
    onRadioOnChanged: if (!radioOn) reset()
    onSelectedChanged: if (!selected && phase !== "idle") reset()

    Binding {
        target: wifi.adapter
        property: "scannerEnabled"
        value: wifi.visible && wifi.radioOn
        when: wifi.adapter !== null
        restoreMode: Binding.RestoreNone
    }

    Timer {
        id: deadline
        interval: 40000
        onTriggered: wifi.fail("This is taking longer than expected. Check the signal and try again.", wifi.usedPassword)
    }

    Connections {
        target: wifi.selected

        function onConnectedChanged() {
            if (wifi.selected?.connected) wifi.reset();
        }

        function onConnectionFailed(reason) {
            if (!wifi.joining) return;
            if (reason === ConnectionFailReason.NoSecrets && wifi.supportsPassword(wifi.selected)) {
                wifi.fail("Check the password and try again.", true);
            } else if (reason === ConnectionFailReason.WifiNetworkLost) {
                wifi.fail("The network is out of range.", wifi.usedPassword);
            } else if (reason === ConnectionFailReason.WifiAuthTimeout) {
                wifi.fail("The network did not respond. Try again.", wifi.usedPassword);
            } else {
                wifi.fail("Could not join this network. Try again.", wifi.usedPassword);
            }
        }
    }

    component Caption: Text {
        color: "#a4a4a4"
        font.family: wifi.face
        font.pixelSize: 13
        textFormat: Text.PlainText
    }

    component Action: Button {
        id: control
        property bool primary: false
        font.family: wifi.face
        font.pixelSize: 13
        leftPadding: 12
        rightPadding: 12
        topPadding: 6
        bottomPadding: 6
        palette.buttonText: primary ? "#161616" : "#eeeeee"
        background: Rectangle {
            radius: 6
            color: control.primary ? (control.enabled ? "#e9e9e9" : "#555555")
                : control.hovered || control.visualFocus ? "#3b3b3b" : "#292929"
        }
    }

    component Signal: Row {
        id: bars
        required property real strength
        spacing: 2

        Repeater {
            model: 4
            Rectangle {
                required property int index
                anchors.bottom: parent.bottom
                width: 2
                height: 4 + index * 2
                radius: 1
                color: bars.strength >= (index + 1) / 4 - 0.12 ? "#dfdfdf" : "#484848"
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: wifi.panelColor
        radius: 16
        transformOrigin: Item.TopRight

        opacity: wifi.visible ? 1.0 : 0.0
        scale: wifi.visible ? 1.0 : 0.92
        transform: Translate {
            y: wifi.visible ? 0 : -8
            Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        ColumnLayout {
            id: contents
            x: 13
            y: 13
            width: parent.width - 26
            spacing: 10

            RowLayout {
                Layout.fillWidth: true

                Caption {
                    Layout.fillWidth: true
                    text: "Wi-Fi"
                    color: "#f5f5f5"
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                }

                Switch {
                    checked: wifi.radioOn
                    enabled: wifi.adapter !== null && Networking.wifiHardwareEnabled && !wifi.joining
                    Accessible.name: "Wi-Fi"
                    onToggled: Networking.wifiEnabled = checked
                    palette.highlight: "#9fc6ed"
                    palette.button: "#393939"
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: "#303030"
            }

            Caption {
                Layout.fillWidth: true
                visible: !wifi.radioOn || !wifi.adapter
                text: !wifi.adapter ? "Wi-Fi adapter unavailable"
                    : !Networking.wifiHardwareEnabled ? "Wi-Fi is blocked by hardware" : "Wi-Fi is off"
            }

            Rectangle {
                visible: wifi.radioOn && wifi.connectedNetwork !== null
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                color: "#252525"
                radius: 9

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 9

                    Rectangle { width: 6; height: 6; radius: 3; color: "#9fc6ed" }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Caption {
                            Layout.fillWidth: true
                            text: wifi.connectedNetwork?.name ?? ""
                            color: "#f5f5f5"
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Caption { text: "Connected"; font.pixelSize: 11 }
                    }

                    Signal { strength: wifi.connectedNetwork?.signalStrength ?? 0 }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: wifi.radioOn && wifi.adapter !== null && wifi.phase === "idle"
                spacing: 4

                Caption { text: "Nearby networks"; font.weight: Font.DemiBold }
                Caption {
                    Layout.fillWidth: true
                    visible: nearby.count === 0
                    text: "Looking for networks…"
                }
                ListView {
                    id: nearby
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(count * 42, 168)
                    visible: count > 0
                    clip: true

                    model: ScriptModel {
                        values: Array.from(wifi.networks).filter(network => network.name && !network.connected
                            && (network.signalStrength > 0 || network.stateChanging)).sort((a, b) =>
                            Number(b.known) - Number(a.known) || a.name.localeCompare(b.name))
                    }

                    delegate: Button {
                        id: networkButton
                        required property WifiNetwork modelData
                        width: ListView.view.width
                        height: 42
                        horizontalPadding: 9
                        verticalPadding: 3
                        Accessible.name: modelData.name + ", " + wifi.securityLabel(modelData)
                        onClicked: wifi.choose(modelData)
                        contentItem: RowLayout {
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Caption {
                                    Layout.fillWidth: true
                                    text: networkButton.modelData.name
                                    color: "#f5f5f5"
                                    elide: Text.ElideRight
                                }
                                Caption {
                                    text: networkButton.modelData.known ? "Saved" : wifi.securityLabel(networkButton.modelData)
                                    font.pixelSize: 11
                                }
                            }
                            Signal { strength: networkButton.modelData.signalStrength }
                        }
                        background: Rectangle {
                            radius: 6
                            color: networkButton.hovered || networkButton.visualFocus ? "#292929" : "transparent"
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: wifi.radioOn && wifi.selected !== null
                spacing: 8

                Caption {
                    Layout.fillWidth: true
                    text: wifi.selected?.name ?? ""
                    elide: Text.ElideRight
                    color: "#f5f5f5"
                    font.weight: Font.DemiBold
                    font.pixelSize: 16
                }

                Caption {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: wifi.errorText || (wifi.joining ? "Joining…"
                        : wifi.phase === "unsupported" ? "This network needs a configured connection profile."
                        : wifi.asksForPassword ? "Enter the network password to join."
                        : wifi.selected?.known ? "Use the saved connection."
                        : "Join this network?")
                    color: wifi.errorText ? "#ff9d95" : "#a4a4a4"
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: wifi.asksForPassword
                    spacing: 6
                    TextField {
                        id: secret
                        Layout.fillWidth: true
                        placeholderText: "Password"
                        Accessible.name: "Wi-Fi password"
                        echoMode: reveal.checked ? TextInput.Normal : TextInput.Password
                        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                        font.family: wifi.face
                        font.pixelSize: 13
                        color: "#eeeeee"
                        placeholderTextColor: "#a4a4a4"
                        onAccepted: wifi.join()
                        background: Rectangle {
                            color: "#252525"
                            radius: 6
                            border.color: secret.activeFocus ? "#8caccb" : "#444444"
                        }
                    }
                    Action {
                        id: reveal
                        text: checked ? "Hide" : "Show"
                        Accessible.name: checked ? "Hide password" : "Show password"
                        checkable: true
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Item { Layout.fillWidth: true }
                    Action {
                        text: "Back"
                        visible: !wifi.joining
                        onClicked: wifi.reset()
                    }
                    Action {
                        primary: true
                        visible: wifi.phase !== "unsupported"
                        enabled: !wifi.joining && !wifi.selected?.stateChanging && (!wifi.asksForPassword || secret.length > 0)
                        text: wifi.joining ? "Joining…" : wifi.errorText && !wifi.asksForPassword ? "Retry" : "Join"
                        onClicked: wifi.join()
                    }
                }
            }
        }
    }
}
