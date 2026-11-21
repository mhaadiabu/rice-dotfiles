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
        color: "#101418"

        // Set these in the deployed copy to preselect an account.
        readonly property string defaultUser: ""
        readonly property string accountLabel: defaultUser
        readonly property string typeface: "Aptos Narrow"
        readonly property real layoutScale: Math.min(1, height / 620)
        property string username: defaultUser
        property bool otherUser: !defaultUser
        property bool waiting: false
        property bool promptOpen: false
        property bool echoResponse: false
        property string prompt: "Enter Password"
        property string notice: ""
        property color noticeColor: "#bfbfc4"

        function startAuthentication() {
            if (!Greetd.available || waiting || Greetd.state !== GreetdState.Inactive)
                return;
            waiting = true;
            Greetd.createSession(username);
        }

        function submit() {
            if (!Greetd.available || waiting)
                return;
            notice = "";
            if (promptOpen) {
                const answer = entry.text;
                entry.clear();
                promptOpen = false;
                waiting = true;
                Greetd.respond(answer);
            } else if (otherUser && entry.text.trim()) {
                username = entry.text.trim();
                entry.clear();
                startAuthentication();
            } else if (!otherUser && entry.text.length) {
                startAuthentication();
            }
        }

        function switchUser() {
            otherUser = !otherUser;
            promptOpen = false;
            notice = "";
            entry.clear();
            username = otherUser ? "" : defaultUser;
            entry.forceActiveFocus();
        }

        function finishAttempt(message) {
            waiting = false;
            promptOpen = false;
            entry.clear();
            noticeColor = "#ffb1b1";
            notice = message;
            entry.forceActiveFocus();
        }

        Connections {
            target: Greetd

            function onAuthMessage(message, error, responseRequired, echoResponse) {
                if (responseRequired) {
                    const label = message.trim().replace(/:$/, "");
                    const isPassword = !echoResponse && /^password$/i.test(label);
                    // Submit the prefilled account's entry only to its first password prompt.
                    if (!greeter.otherUser && isPassword && entry.text.length) {
                        const answer = entry.text;
                        entry.clear();
                        Greetd.respond(answer);
                        return;
                    }
                    greeter.prompt = isPassword || !label ? "Enter Password" : label;
                    greeter.echoResponse = echoResponse;
                    entry.clear();
                    greeter.promptOpen = true;
                    greeter.waiting = false;
                    entry.forceActiveFocus();
                } else {
                    greeter.noticeColor = error ? "#ffb1b1" : "#bfbfc4";
                    greeter.notice = message;
                }
            }

            function onAuthFailure(message) {
                greeter.finishAttempt(message || "Sign-in failed. Try again.");
            }

            function onError(error) {
                Greetd.cancelSession();
                greeter.finishAttempt(error || "Could not start the session. Try again.");
            }

            function onReadyToLaunch() {
                greeter.waiting = true;
                greeter.noticeColor = "#bfbfc4";
                greeter.notice = "Signing in…";
                Greetd.launch(["/usr/bin/niri-session"], [
                    "XDG_SESSION_TYPE=wayland",
                    "XDG_CURRENT_DESKTOP=niri"
                ]);
            }
        }

        Image {
            anchors.fill: parent
            source: "lock-background.jpg"
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -190 * greeter.layoutScale
            text: Qt.formatDateTime(clock.date, "h:mm AP")
            color: "#f5f5f7"
            font.family: greeter.typeface
            font.pixelSize: 64 * greeter.layoutScale
        }

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -130 * greeter.layoutScale
            text: Qt.formatDateTime(clock.date, "dddd, MMMM dd")
            color: "#bfd4d4d8"
            font.family: greeter.typeface
            font.pixelSize: 17
        }

        Rectangle {
            id: portrait
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -25 * greeter.layoutScale
            width: 90 * greeter.layoutScale
            height: width
            radius: width / 2
            color: "transparent"
            visible: !greeter.otherUser && avatar.status === Image.Ready

            Image {
                id: avatar
                anchors.fill: parent
                source: greeter.defaultUser ? "account-avatar.png" : ""
                fillMode: Image.PreserveAspectCrop
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: 2
                border.color: "#26ffffff"
            }
        }

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 35 * greeter.layoutScale
            text: greeter.otherUser ? greeter.username || "Other user" : greeter.accountLabel
            textFormat: Text.PlainText
            color: "#e6f5f5f7"
            font.family: greeter.typeface
            font.pixelSize: 16
        }

        TextField {
            id: entry
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 95 * greeter.layoutScale
            width: 260
            height: 44
            leftPadding: 14
            rightPadding: 14
            focus: true
            readOnly: greeter.waiting
            selectByMouse: true
            horizontalAlignment: TextInput.AlignHCenter
            placeholderText: greeter.waiting ? "Please wait…" :
                greeter.promptOpen ? greeter.prompt : greeter.otherUser ? "Username" : "Enter Password"
            Accessible.name: placeholderText
            echoMode: (greeter.promptOpen ? !greeter.echoResponse : !greeter.otherUser) ?
                TextInput.Password : TextInput.Normal
            inputMethodHints: echoMode === TextInput.Password ?
                Qt.ImhNoPredictiveText | Qt.ImhSensitiveData : Qt.ImhNoPredictiveText
            font.family: greeter.typeface
            font.pixelSize: 16
            color: "#f5f5f7"
            placeholderTextColor: "#bfbfc4"
            selectionColor: "#6ea8fe"
            selectedTextColor: "#101418"
            onAccepted: greeter.submit()
            background: Rectangle {
                radius: 13
                color: "#a6141418"
                border.color: greeter.notice && Qt.colorEqual(greeter.noticeColor, "#ffb1b1") ?
                    "#ffb1b1" : entry.activeFocus ? "#80ffffff" : "#26ffffff"
            }
        }

        Text {
            anchors.top: entry.bottom
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(380, greeter.width - 40)
            text: Greetd.available ? greeter.notice : "Preview. Sign-in is disabled."
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            color: greeter.noticeColor
            font.family: greeter.typeface
            font.pixelSize: 14
        }

        Button {
            id: switchButton
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 20
            visible: !!greeter.defaultUser
            text: greeter.otherUser ? "Back to " + greeter.accountLabel : "Switch user"
            enabled: Greetd.available && Greetd.state === GreetdState.Inactive && !greeter.waiting
            hoverEnabled: true
            onClicked: greeter.switchUser()

            contentItem: Text {
                text: switchButton.text
                color: switchButton.enabled ? "#f5f5f7" : "#bfbfc4"
                font.family: greeter.typeface
                font.pixelSize: 15
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            background: Rectangle {
                radius: 10
                color: switchButton.hovered ? "#cf141418" : "#a6141418"
                border.color: switchButton.visualFocus ? "#80ffffff" : "transparent"
            }
        }
    }
}
