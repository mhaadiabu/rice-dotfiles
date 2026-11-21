import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Services.Greetd

ShellRoot {
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Window {
        id: greeter

        title: "Sign in"
        width: 960
        height: 600
        minimumWidth: 440
        minimumHeight: 440
        visibility: Greetd.available ? Window.FullScreen : Window.Windowed
        color: "#111820"
        palette {
            window: "#171b21"
            windowText: "#f0f3f6"
            base: "#232b35"
            text: "#f0f3f6"
            placeholderText: "#aebac9"
            button: "#2a3441"
            buttonText: "#f0f3f6"
            highlight: "#a9c9eb"
            highlightedText: "#111820"
        }

        property bool waiting: false
        property bool promptOpen: false
        property bool echoResponse: false
        property string prompt: ""
        property string notice: ""
        property color noticeColor: "#c6d0da"
        property int sessionIndex: 0
        readonly property var sessions: [
            { name: "Niri", command: "/usr/bin/niri-session", desktop: "niri" }
        ]
        readonly property var selectedSession: sessions[sessionIndex]

        component LoginField: TextField {
            leftPadding: 15
            rightPadding: 10
            font.family: "Inter"
            font.pixelSize: 13
            color: "white"
            placeholderTextColor: "#d2dae3"
            background: null
        }

        function submit() {
            if (!Greetd.available || waiting) return;
            if (promptOpen) {
                waiting = true;
                promptOpen = false;
                const value = response.text;
                response.clear();
                Greetd.respond(value);
            } else if (Greetd.state === GreetdState.Inactive && account.text.trim()) {
                notice = "";
                waiting = true;
                Greetd.createSession(account.text.trim());
            }
        }

        function reset(message) {
            waiting = false;
            promptOpen = false;
            response.clear();
            noticeColor = "#ffc1b6";
            notice = message;
            account.forceActiveFocus();
        }

        Connections {
            target: Greetd

            function onAuthMessage(message, error, responseRequired, echoResponse) {
                if (responseRequired) {
                    greeter.prompt = message.trim().replace(/:$/, "") || "Password";
                    greeter.echoResponse = echoResponse;
                    response.clear();
                    greeter.promptOpen = true;
                    greeter.waiting = false;
                    response.forceActiveFocus();
                } else {
                    greeter.noticeColor = error ? "#ffc1b6" : "#c6d0da";
                    greeter.notice = message;
                }
            }

            function onAuthFailure(message) {
                greeter.reset(message || "Sign-in failed. Try again.");
            }

            function onError(error) {
                Greetd.cancelSession();
                greeter.reset(error || "Could not start the session.");
            }

            function onReadyToLaunch() {
                greeter.waiting = true;
                greeter.noticeColor = "#c6d0da";
                const selected = greeter.selectedSession;
                greeter.notice = "Starting " + selected.name + "…";
                Greetd.launch([selected.command], [
                    "XDG_SESSION_TYPE=wayland",
                    "XDG_CURRENT_DESKTOP=" + selected.desktop
                ]);
            }
        }

        Image {
            anchors.fill: parent
            source: "rocket.jpg"
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: "#ac090e16" }
                GradientStop { position: 0.52; color: "#17090e16" }
                GradientStop { position: 1; color: "#cf090e16" }
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Math.max(30, Math.round(parent.height * 0.105))
            spacing: 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "dddd, MMMM d")
                color: "#e8edf4"
                font.family: "Inter"
                font.pixelSize: Math.max(16, Math.min(23, greeter.height * 0.032))
                font.weight: Font.Medium
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: "white"
                font.family: "Inter"
                font.pixelSize: Math.max(68, Math.min(128, greeter.height * 0.16))
                font.weight: Font.Normal
                font.letterSpacing: -3
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.max(48, Math.round(parent.height * 0.08))
            width: 248
            spacing: 9

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 66
                height: 66
                radius: 33
                color: "#ba243341"
                border.color: "#4affffff"

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 14
                    width: 18
                    height: 18
                    radius: height / 2
                    color: "#e0eaf5"
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 36
                    width: 32
                    height: 16
                    radius: height / 2
                    color: "#e0eaf5"
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: account.text.trim() || "Sign in"
                textFormat: Text.PlainText
                color: "white"
                font.family: "Inter"
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }

            Rectangle {
                width: parent.width
                height: 38
                radius: 19
                color: "#b12b3642"
                border.color: account.activeFocus || response.activeFocus ? "#889eb4" : "#42ffffff"

                LoginField {
                    id: account
                    anchors.left: parent.left
                    anchors.right: submitButton.left
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    visible: !greeter.promptOpen && !greeter.waiting
                    placeholderText: "Username"
                    focus: true
                    selectByMouse: true
                    onAccepted: greeter.submit()
                }

                LoginField {
                    id: response
                    anchors.left: parent.left
                    anchors.right: submitButton.left
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    visible: greeter.promptOpen
                    placeholderText: greeter.prompt
                    Accessible.name: greeter.prompt
                    echoMode: greeter.echoResponse ? TextInput.Normal : TextInput.Password
                    inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhSensitiveData
                    onAccepted: greeter.submit()
                }

                BusyIndicator {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    running: greeter.waiting
                    visible: running
                }

                Button {
                    id: submitButton
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30
                    height: 30
                    visible: !greeter.waiting
                    enabled: Greetd.available && (greeter.promptOpen || account.text.trim().length > 0)
                    Accessible.name: "Continue"
                    onClicked: greeter.submit()

                    contentItem: Text {
                        text: "→"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: submitButton.enabled ? "white" : "#9baaba"
                        font.pixelSize: 18
                    }

                    background: Rectangle {
                        radius: 15
                        color: submitButton.down ? "#657687" : "#455566"
                        border.color: submitButton.visualFocus ? "#b9d7f3" : "transparent"
                    }
                }
            }

            Text {
                width: parent.width
                height: Math.max(28, implicitHeight)
                horizontalAlignment: Text.AlignHCenter
                text: Greetd.available ? greeter.notice : "Preview · sign-in is disabled"
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: greeter.noticeColor
                font.family: "Inter"
                font.pixelSize: 11
            }
        }

        Button {
            id: sessionButton
            visible: greeter.sessions.length > 1
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 22
            width: 42
            height: 42
            enabled: !greeter.waiting
            hoverEnabled: true
            Accessible.name: "Desktop session: " + greeter.selectedSession.name
            ToolTip.visible: hovered && !sessionMenu.opened
            ToolTip.text: Accessible.name
            ToolTip.delay: 400
            onClicked: sessionMenu.popup(width - sessionMenu.width, -sessionMenu.implicitHeight - 8)

            contentItem: Item {
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -2
                    width: 18
                    height: 12
                    radius: 2
                    color: "transparent"
                    border.color: "#f0f3f6"
                    border.width: 1.5
                }
                Rectangle {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 6
                    width: 2
                    height: 4
                    color: "#f0f3f6"
                }
                Rectangle {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 8
                    width: 8
                    height: 1
                    color: "#f0f3f6"
                }
            }

            background: Rectangle {
                radius: 21
                color: sessionButton.hovered || sessionMenu.opened ? "#d33c4a59" : "#b12b3642"
                border.color: sessionButton.visualFocus ? "#b9d7f3" : "#42ffffff"
            }

            Menu {
                id: sessionMenu
                parent: sessionButton
                width: 156
                padding: 5

                ButtonGroup {
                    id: sessionChoices
                }

                MenuItem {
                    text: "Niri"
                    checkable: true
                    checked: greeter.sessionIndex === 0
                    ButtonGroup.group: sessionChoices
                    onTriggered: greeter.sessionIndex = 0
                }

                background: Rectangle {
                    radius: 12
                    color: "#f0232b35"
                    border.color: "#42ffffff"
                }
            }
        }
    }
}
