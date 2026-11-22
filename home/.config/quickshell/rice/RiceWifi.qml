import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking

FocusScope {
    id: wifi
    required property string face
    required property RiceTheme theme

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
    implicitHeight: contents.implicitHeight + theme.panelPadding * 2
    required property bool motionEnabled

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

    onVisibleChanged: {
        if (visible) forceActiveFocus();
        else if (!joining) reset();
    }
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
        color: wifi.theme.muted
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
        palette.buttonText: primary && enabled ? wifi.theme.inverseInk : wifi.theme.ink
        background: Rectangle {
            radius: wifi.theme.radiusControl
            color: control.primary ? (control.enabled ? wifi.theme.ink : wifi.theme.card)
                : control.hovered || control.visualFocus ? wifi.theme.hover : wifi.theme.card
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
                color: bars.strength >= (index + 1) / 4 - 0.12 ? wifi.theme.ink : wifi.theme.line
            }
        }
    }

    MouseArea { anchors.fill: parent }

    RiceMenuSurface {
        anchors.fill: parent
        color: wifi.theme.surface
        radius: wifi.theme.radiusPanel
        motionEnabled: wifi.motionEnabled

        ColumnLayout {
            id: contents
            x: wifi.theme.panelPadding
            y: wifi.theme.panelPadding
            width: parent.width - wifi.theme.panelPadding * 2
            spacing: wifi.theme.gap

            RowLayout {
                Layout.fillWidth: true

                Caption {
                    Layout.fillWidth: true
                    text: "Wi-Fi"
                    color: wifi.theme.ink
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                }

                Switch {
                    id: radioSwitch
                    padding: 7
                    checked: wifi.radioOn
                    enabled: wifi.adapter !== null && Networking.wifiHardwareEnabled && !wifi.joining
                    Accessible.name: "Wi-Fi"
                    onToggled: Networking.wifiEnabled = checked

                    indicator: Rectangle {
                        implicitWidth: 36
                        implicitHeight: 20
                        x: radioSwitch.leftPadding
                        anchors.verticalCenter: parent.verticalCenter
                        radius: height / 2
                        color: radioSwitch.checked
                            ? (radioSwitch.enabled ? wifi.theme.accent : wifi.theme.outline)
                            : (radioSwitch.enabled ? wifi.theme.hover : wifi.theme.card)
                        border.color: radioSwitch.visualFocus ? wifi.theme.ink
                            : radioSwitch.checked ? "transparent" : wifi.theme.outline

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x: radioSwitch.checked ? parent.width - width - 3 : 3
                            width: 14
                            height: 14
                            radius: height / 2
                            color: radioSwitch.enabled ? "#ffffff" : wifi.theme.muted
                        }
                    }
                }
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
                Layout.preferredHeight: 52
                color: wifi.theme.card
                radius: wifi.theme.radiusCard

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    Rectangle { width: 6; height: 6; radius: 3; color: wifi.theme.accent }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Caption {
                            Layout.fillWidth: true
                            text: wifi.connectedNetwork?.name ?? ""
                            color: wifi.theme.ink
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
                spacing: 6

                Caption { Layout.leftMargin: 2; text: "Nearby networks"; font.weight: Font.DemiBold }
                Caption {
                    Layout.fillWidth: true
                    visible: nearby.count === 0
                    text: "Looking for networks…"
                }
                // Rows sit 4px inside the card, so their radius is the card's minus 4.
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: nearby.height + 8
                    visible: nearby.count > 0
                    radius: wifi.theme.radiusCard
                    color: wifi.theme.card

                RiceListView {
                    id: nearby
                    x: 4
                    y: 4
                    width: parent.width - 8
                    height: Math.min(count * 42, 168)
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
                        horizontalPadding: 10
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
                                    color: wifi.theme.ink
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
                            radius: wifi.theme.radiusControl
                            color: networkButton.hovered || networkButton.visualFocus ? wifi.theme.hover : "transparent"
                        }
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
                    color: wifi.theme.ink
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
                    color: wifi.errorText ? wifi.theme.error : wifi.theme.muted
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
                        color: wifi.theme.ink
                        placeholderTextColor: wifi.theme.muted
                        selectionColor: wifi.theme.accent
                        selectedTextColor: "#ffffff"
                        onAccepted: wifi.join()
                        background: Rectangle {
                            color: wifi.theme.card
                            radius: wifi.theme.radiusControl
                            border.color: secret.activeFocus ? wifi.theme.accent : wifi.theme.outline
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
