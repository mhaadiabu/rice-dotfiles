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
    required property RiceTheme theme
    required property Item host
    required property bool motionEnabled
    required property bool shown
    property bool dnd: false
    onDndChanged: {
        if (!dnd) return;
        bannerTimer.stop();
        if (bannerNotice?.transient) bannerNotice.expire();
        bannerNotice = null;
    }
    property Notification bannerNotice
    property var agenda: []

    Process {
        id: readAgenda
        command: ["khal", "--no-color", "list", "--format", "{start-date}  {start-time}  {title}", "--day-format", "", "today", "7d"]
        stdout: StdioCollector {
            onStreamFinished: center.agenda = text.trim().split("\n").filter(Boolean).slice(0, 2)
        }
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
            if (center.shown || center.dnd) {
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
        palette.buttonText: center.theme.secondary
        background: Rectangle {
            radius: center.theme.radiusControl
            color: control.hovered || control.visualFocus || control.down ? center.theme.hover : "transparent"
        }
    }

    component NoticeCard: Item {
        id: card
        property real cornerRadius: center.theme.radiusCard
        required property Notification notice
        property bool showActions: true
        readonly property var display: center.presentation(notice)
        readonly property string appName: display.name
        readonly property string summary: center.readableText(notice?.summary)
        readonly property string message: display.message
        readonly property var actions: showActions ? notice?.actions ?? [] : []
        implicitHeight: Math.max(52, content.implicitHeight + 20)
        property real swipeX: 0
        property real dragStartX: 0
        property bool dismissing: false
        readonly property bool interacting: drag.active || wheelEnd.running || settle.running
        readonly property real dismissDistance: Math.min(104, width * 0.28)

        function dismiss() {
            const closing = notice;
            if (closing && center.bannerNotice === closing) {
                bannerTimer.stop();
                center.bannerNotice = null;
            }
            closing?.dismiss();
        }

        function finishSwipe() {
            dismissing = Math.abs(swipeX) >= dismissDistance && swipeX !== 0;
            if (!center.motionEnabled) {
                swipeX = 0;
                if (dismissing) dismiss();
                return;
            }
            settle.to = dismissing ? Math.sign(swipeX) * (width + 16) : 0;
            settle.restart();
        }

        onNoticeChanged: {
            wheelEnd.stop();
            settle.stop();
            swipeX = 0;
            dismissing = false;
        }

        NumberAnimation {
            id: settle
            target: card
            property: "swipeX"
            duration: 145
            easing.type: Easing.OutCubic
            onFinished: if (card.dismissing) card.dismiss()
        }

        Timer {
            id: wheelEnd
            interval: 110
            onTriggered: card.finishSwipe()
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            scrollGestureEnabled: true

            onWheel: event => {
                const delta = event.pixelDelta;
                event.accepted = Boolean(card.notice) && Math.abs(delta.x) > Math.abs(delta.y);
                if (!event.accepted || card.dismissing) return;
                settle.stop();
                card.swipeX = Math.max(-card.width, Math.min(card.width, card.swipeX + delta.x * 2.5));
                wheelEnd.restart();
            }
        }

        DragHandler {
            id: drag
            target: null
            yAxis.enabled: false
            enabled: Boolean(card.notice) && !card.dismissing
            onActiveChanged: {
                if (active) {
                    wheelEnd.stop();
                    settle.stop();
                    card.dragStartX = card.swipeX;
                } else {
                    card.finishSwipe();
                }
            }
            onActiveTranslationChanged: {
                if (active) card.swipeX = card.dragStartX + activeTranslation.x;
            }
        }

        Rectangle {
            anchors.fill: parent
            color: center.theme.card
            radius: card.cornerRadius
            opacity: 1 - Math.min(0.65, Math.abs(card.swipeX) / Math.max(1, width))
            transform: Translate { x: card.swipeX }

            Rectangle {
                x: 11
                y: 11
                width: 30
                height: 30
                radius: center.theme.radiusControl
                color: appIcon.status === Image.Ready ? "transparent" : center.theme.selected

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
                    color: center.theme.ink
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
                        color: center.theme.muted
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
                        onClicked: card.dismiss()
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
                    color: center.theme.ink
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
                    color: center.theme.secondary
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
                                color: action.primary ? center.theme.ink : center.theme.secondary
                                font: action.font
                                horizontalAlignment: Text.AlignHCenter
                            }

                            background: Rectangle {
                                radius: center.theme.radiusControl
                                color: action.hovered || action.visualFocus || action.down ? center.theme.selected
                                    : action.primary ? center.theme.hover : "transparent"
                                border.color: action.primary ? "transparent" : center.theme.line
                            }
                        }
                    }
                }
            }
        }
    }

    FocusScope {
        parent: center.host
        visible: center.shown
        x: Math.round(center.trigger.x + (center.trigger.width - width) / 2)
        y: center.theme.popoverTop
        width: Math.min(348, parent.width)
        height: Math.min(488, parent.height - 16)

        onVisibleChanged: {
            if (!visible) return;
            if (center.bannerNotice?.transient) center.bannerNotice.expire();
            center.bannerNotice = null;
            forceActiveFocus();
            readAgenda.running = true;
        }

        MouseArea { anchors.fill: parent }

        RiceMenuSurface {
            anchors.fill: parent
            color: center.theme.surface
            radius: center.theme.radiusPanel
            revealOrigin: Item.Top
            motionEnabled: center.motionEnabled

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: center.theme.panelPadding
                spacing: center.theme.gap

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: "Notifications"
                        color: center.theme.ink
                        font.family: center.face
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                    }
                    SmallButton {
                        text: "Clear all"
                        visible: notices.count > 0
                        onClicked: center.clearAll()
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    Flickable {
                        id: feed
                        anchors.fill: parent
                        anchors.rightMargin: 7
                        clip: true
                        contentWidth: width
                        contentHeight: cards.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        flickableDirection: Flickable.VerticalFlick
                        acceptedButtons: Qt.NoButton

                        RiceTrackpadScroll { viewport: feed }

                        Column {
                            id: cards
                            width: feed.width
                            spacing: 6

                            Repeater {
                                id: notices
                                model: ScriptModel {
                                    values: Array.from(server.trackedNotifications.values).reverse()
                                        .filter(notice => !notice.transient)
                                }
                                delegate: NoticeCard {
                                    required property Notification modelData
                                    width: cards.width
                                    height: implicitHeight
                                    notice: modelData
                                }
                            }
                        }

                        ScrollBar.vertical: ScrollBar {
                            parent: feed.parent
                            x: feed.width + 2
                            height: feed.height
                            width: 5
                            palette.mid: center.theme.outline
                            palette.dark: center.theme.ink
                            policy: ScrollBar.AsNeeded
                            minimumSize: 0.07
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: notices.count === 0
                        text: "No notifications"
                        color: center.theme.muted
                        font.family: center.face
                        font.pixelSize: 14
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: calendarColumn.implicitHeight + 24
                    radius: center.theme.radiusCard
                    color: center.theme.tile

                    ColumnLayout {
                        id: calendarColumn
                        anchors { fill: parent; margins: 12 }
                        spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: Qt.formatDateTime(center.today, "MMMM yyyy")
                            color: center.theme.ink
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
                            color: center.theme.muted
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
                                color: center.theme.ink
                            }
                            Text {
                                anchors.centerIn: parent
                                opacity: cell.today || cell.model.month === calendar.month ? 1 : 0.68
                                text: cell.model.day
                                color: cell.today ? center.theme.inverseInk : cell.model.month === calendar.month ? center.theme.ink : center.theme.muted
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
                            color: center.theme.secondary
                            font.family: center.face
                            font.pixelSize: 12
                        }
                    }
                    }
                }
            }
        }
    }

    PanelWindow {
        anchors { top: true; right: true }
        margins { top: center.theme.popoverTop; right: center.theme.popoverSide }
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
            onInteractingChanged: {
                if (interacting) bannerTimer.stop();
                else if (center.bannerNotice) bannerTimer.restart();
            }
        }
    }
}
