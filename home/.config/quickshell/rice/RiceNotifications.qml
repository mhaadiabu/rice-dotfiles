import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Scope {
    id: center

    required property var bar
    required property var trigger
    required property date today
    required property string face
    required property color panelColor
    property alias shown: popup.visible
    property Notification bannerNotice
    property var agenda: []

    Process {
        id: readAgenda
        command: ["khal", "--no-color", "list", "--format", "{start-date}  {start-time}  {title}", "--day-format", "", "today", "7d"]
        stdout: StdioCollector {
            onStreamFinished: center.agenda = text.trim().split("\n").filter(Boolean).slice(0, 2)
        }
    }

    function toggle() {
        popup.visible = !popup.visible;
    }

    function clearAll() {
        const notices = Array.from(server.trackedNotifications.values);
        for (const notice of notices) {
            if (!notice.transient) notice.dismiss();
        }
    }

    // Notifications sometimes carry HTML even when the server advertises plain text.
    function readableText(value) {
        const entities = { amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", nbsp: " " };
        return (value || "")
            .replace(/<br\s*\/?\s*>|<\/p\s*>/gi, "\n")
            .replace(/<\/?(?:a|b|strong|i|em|u|p|span|img)\b[^>]*>/gi, "")
            .replace(/&(amp|lt|gt|quot|apos|nbsp|#\d+|#x[0-9a-f]+);/gi, (match, entity) => {
                const key = entity.toLowerCase();
                if (!key.startsWith("#")) return entities[key];
                const number = key.startsWith("#x") ? parseInt(key.substring(2), 16) : parseInt(key.substring(1), 10);
                return number > 0 && number <= 0x10ffff ? String.fromCodePoint(number) : match;
            })
            .trim();
    }

    function iconSource(notice) {
        if (!notice) return "";
        const app = DesktopEntries.heuristicLookup(notice.desktopEntry || notice.appName);
        for (const icon of [app?.icon, notice.appIcon]) {
            if (!icon) continue;
            if (icon.startsWith("/")) return "file://" + icon;
            if (icon.startsWith("file://")) return icon;
            const themed = Quickshell.iconPath(icon, true);
            if (themed) return themed;
        }
        return "";
    }

    function originHost(value) {
        const match = value.trim().match(/^(?:https?:\/\/)?((?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9-]+)(?::\d+)?\/?$/i);
        return match ? match[1].toLowerCase() : "";
    }

    function presentation(notice) {
        const appName = notice?.appName || "Notification";
        const message = readableText(notice?.body);
        const originHint = notice?.hints?.["x-kde-origin-name"];
        const origin = typeof originHint === "string" ? readableText(originHint) : "";
        const browser = /ardia|chrom(e|ium)|firefox|brave|vivaldi|helium|microsoft-edge|epiphany|\bzen\b|opera/i
            .test(appName + " " + (notice?.desktopEntry || ""));
        const firstLine = message.split("\n", 1)[0];
        const bodyHost = browser ? originHost(firstLine) : "";
        const host = originHost(origin) || bodyHost;

        if (!host && !origin)
            return { name: appName, message, icon: iconSource(notice) };

        const whatsapp = host === "web.whatsapp.com" || host === "whatsapp.com";
        // Use local images supplied with the notification. Opening the panel never fetches remote images.
        const image = notice?.image || "";
        const icon = whatsapp ? Quickshell.shellPath("icons/sites/whatsapp.ico")
            : /^(?:file:\/\/|image:\/\/)/.test(image) ? image : "";
        return {
            name: whatsapp ? "WhatsApp" : host || origin,
            message: bodyHost && bodyHost === host ? message.slice(firstLine.length).trim() : message,
            icon
        };
    }

    NotificationServer {
        id: server
        actionsSupported: true
        persistenceSupported: true
        imageSupported: true
        extraHints: ["x-kde-origin-name"]
        onNotification: notice => {
            notice.tracked = true;
            if (notice.lastGeneration) return;
            if (center.shown) {
                if (notice.transient) notice.expire();
                return;
            }
            if (center.bannerNotice?.transient && center.bannerNotice !== notice)
                center.bannerNotice.expire();
            center.bannerNotice = notice;
            bannerTimer.restart();
        }
    }

    Timer {
        id: bannerTimer
        onTriggered: {
            if (center.bannerNotice?.transient) center.bannerNotice.expire();
            center.bannerNotice = null;
        }
        interval: 5000
    }

    component SmallButton: Button {
        id: control
        font.family: center.face
        font.pixelSize: 13
        flat: true
        hoverEnabled: true
        leftPadding: 8
        rightPadding: 8
        topPadding: 4
        bottomPadding: 4
        palette.buttonText: "#dddddd"
        background: Rectangle {
            radius: 5
            color: control.hovered || control.visualFocus || control.down ? "#1affffff" : "transparent"
        }
    }

    component NoticeCard: Rectangle {
        id: card
        required property Notification notice
        property bool showActions: true
        readonly property var display: center.presentation(notice)
        readonly property string appName: display.name
        readonly property string summary: center.readableText(notice?.summary)
        readonly property string message: display.message
        readonly property var actions: showActions ? notice?.actions ?? [] : []
        implicitHeight: Math.max(52, content.implicitHeight + 20)
        color: "#242424"
        radius: 11

        Rectangle {
            x: 11
            y: 11
            width: 30
            height: 30
            radius: 8
            color: appIcon.status === Image.Ready ? "transparent" : "#3b3e44"

            Image {
                id: appIcon
                anchors.fill: parent
                source: card.display.icon
                sourceSize: Qt.size(60, 60)
                fillMode: Image.PreserveAspectFit
            }

            Text {
                anchors.centerIn: parent
                visible: appIcon.status !== Image.Ready
                text: card.appName.charAt(0).toUpperCase()
                color: "#eeeeee"
                font.family: center.face
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }
        }

        ColumnLayout {
            id: content
            x: 51
            y: 10
            width: parent.width - x - 10
            spacing: 4

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: card.appName
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: "#adadad"
                    font.family: center.face
                    font.pixelSize: 12
                }

                SmallButton {
                    Layout.preferredWidth: 23
                    Layout.preferredHeight: 20
                    text: "×"
                    leftPadding: 0
                    rightPadding: 0
                    topPadding: 0
                    bottomPadding: 0
                    Accessible.name: "Dismiss notification"
                    onClicked: card.notice?.dismiss()
                }
            }

            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: card.summary
                textFormat: Text.PlainText
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                maximumLineCount: 2
                elide: Text.ElideRight
                color: "#f5f5f5"
                font.family: center.face
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }

            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: card.message
                textFormat: Text.PlainText
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                maximumLineCount: 3
                elide: Text.ElideRight
                color: "#cecece"
                font.family: center.face
                font.pixelSize: 13
            }

            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 4
                visible: card.actions.length > 0
                spacing: 6

                Repeater {
                    model: card.actions
                    SmallButton {
                        id: action
                        required property var modelData
                        readonly property bool primary: modelData.identifier === "default"
                        text: primary ? "Open" : center.readableText(modelData.text) || "Open"
                        width: Math.min(implicitWidth, parent.width)
                        onClicked: modelData.invoke()

                        contentItem: Text {
                            text: action.text
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: action.primary ? "#f5f5f5" : "#cecece"
                            font: action.font
                            horizontalAlignment: Text.AlignHCenter
                        }

                        background: Rectangle {
                            radius: 5
                            color: action.hovered || action.visualFocus || action.down ? "#494949"
                                : action.primary ? "#383838" : "transparent"
                            border.color: action.primary ? "transparent" : "#444444"
                        }
                    }
                }
            }
        }
    }

    PopupWindow {
        id: popup
        anchor.window: center.bar
        anchor.rect.x: Math.round(center.trigger.x + (center.trigger.width - implicitWidth) / 2)
        anchor.rect.y: center.bar.height + 4
        implicitWidth: Math.min(348, center.bar.width)
        implicitHeight: Math.min(488, (center.bar.screen?.height ?? 768) - center.bar.height - 16)
        grabFocus: true
        color: "transparent"

        onVisibleChanged: {
            if (!visible) return;
            if (center.bannerNotice?.transient) center.bannerNotice.expire();
            center.bannerNotice = null;
            panel.forceActiveFocus();
            readAgenda.running = true;
        }

        Rectangle {
            id: panel
            anchors.fill: parent
            color: center.panelColor
            radius: 24
            transformOrigin: Item.Top

            opacity: popup.visible ? 1.0 : 0.0
            scale: popup.visible ? 1.0 : 0.92
            transform: Translate {
                y: popup.visible ? 0 : -8
                Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            }
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Keys.onEscapePressed: popup.visible = false

            WheelHandler {
                target: null
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    const range = Math.max(0, feed.contentHeight - feed.height);
                    const delta = event.pixelDelta.y || event.angleDelta.y / 120 * 72;
                    if (range > 0 && delta !== 0) {
                        feed.cancelFlick();
                        feed.contentY = Math.max(feed.originY, Math.min(feed.originY + range, feed.contentY - delta));
                        event.accepted = true;
                    }
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 13
                spacing: 9

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: "Notifications"
                        color: "#f5f5f5"
                        font.family: center.face
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                    }
                    SmallButton {
                        text: "Clear all"
                        visible: feed.count > 0
                        onClicked: center.clearAll()
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    ListView {
                        id: feed
                        anchors.fill: parent
                        anchors.rightMargin: 7
                        spacing: 6
                        cacheBuffer: 450
                        boundsBehavior: Flickable.StopAtBounds
                        model: ScriptModel {
                            values: Array.from(server.trackedNotifications.values).reverse()
                                .filter(notice => !notice.transient)
                        }
                        delegate: NoticeCard {
                            required property Notification modelData
                            width: ListView.view.width
                            height: implicitHeight
                            notice: modelData
                        }
                        ScrollBar.vertical: ScrollBar {
                            x: feed.width + 2
                            width: 5
                            policy: ScrollBar.AsNeeded
                            minimumSize: 0.07
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: feed.count === 0
                        text: "No notifications"
                        color: "#a8a8a8"
                        font.family: center.face
                        font.pixelSize: 14
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#303030"
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: Qt.formatDateTime(center.today, "MMMM yyyy")
                        color: "#f5f5f5"
                        font.family: center.face
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }
                    SmallButton {
                        text: "Open Calendar"
                        onClicked: {
                            popup.visible = false;
                            Quickshell.execDetached(["gtk-launch", "rice-calendar"]);
                        }
                    }
                }

                DayOfWeekRow {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 19
                    spacing: 0
                    delegate: Text {
                        required property var model
                        text: model.shortName
                        horizontalAlignment: Text.AlignHCenter
                        color: "#a8a8a8"
                        font.family: center.face
                        font.pixelSize: 11
                    }
                }

                MonthGrid {
                    id: calendar
                    Layout.fillWidth: true
                    Layout.preferredHeight: 126
                    month: center.today.getMonth()
                    year: center.today.getFullYear()
                    spacing: 0
                    delegate: Item {
                        id: cell
                        required property var model
                        readonly property bool today: model.today
                        Rectangle {
                            anchors.centerIn: parent
                            width: 20
                            height: 20
                            radius: 10
                            visible: cell.today
                            color: "#e5e5e5"
                        }
                        Text {
                            anchors.centerIn: parent
                            text: cell.model.day
                            color: cell.today ? "#161616" : cell.model.month === calendar.month ? "#dedede" : "#797979"
                            font.family: center.face
                            font.pixelSize: 12
                        }
                    }
                }
                Repeater {
                    model: center.agenda
                    Text {
                        required property string modelData
                        Layout.fillWidth: true
                        text: modelData
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: "#d4d4d4"
                        font.family: center.face
                        font.pixelSize: 12
                    }
                }

            }
        }
    }

    PanelWindow {
        anchors { top: true; right: true }
        margins { top: 5; right: 12 }
        exclusiveZone: 0
        implicitWidth: 316
        implicitHeight: banner.implicitHeight
        screen: center.bar.screen
        visible: center.bannerNotice !== null && !center.shown
        color: "transparent"

        NoticeCard {
            id: banner
            anchors.fill: parent
            notice: center.bannerNotice
            showActions: false
        }
    }
}
