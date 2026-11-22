import QtQuick
import QtQuick.Controls.Basic
import QtQml.Models
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: dock

    required property RiceTheme theme

    required property bool overviewOpen
    required property string labelFont
    property var pinnedApps: []
    signal pinRequested(string appKey, string desktopId, string name)
    property var windows: []
    property var focusedId: null
    property bool edgeShown: false
    property bool reduceMotion: Quickshell.env("RICE_REDUCE_MOTION") === "1"
    readonly property bool shown: overviewOpen || edgeShown
    readonly property string focusedTitle: windows.find(window => window.id === focusedId)?.title || "Desktop"
    readonly property int bottomGap: 4
    readonly property int tileWidth: Math.min(42, Math.max(20,
        Math.floor((width - 36 - Math.max(0, apps.count - 1) * 3) / Math.max(1, apps.count))))

    anchors { left: true; right: true; bottom: true }
    implicitHeight: 180
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "rice-dock"
    color: "transparent"

    // Keep the layer window still. Only the centered dock or its reveal strip takes input.
    mask: Region { item: pointerArea }

    onOverviewOpenChanged: {
        hideTimer.stop();
        edgeShown = !overviewOpen && pointerArea.hovered;
    }

    function applyWindowEvent(event) {
        if (event.WindowsChanged) {
            windows = event.WindowsChanged.windows;
            focusedId = windows.find(window => window.is_focused)?.id ?? null;
        } else if (event.WindowOpenedOrChanged) {
            const window = event.WindowOpenedOrChanged.window;
            const next = windows.slice();
            const row = next.findIndex(item => item.id === window.id);
            if (row < 0) next.push(window);
            else next[row] = window;
            windows = next;
            if (window.is_focused) focusedId = window.id;
        } else if (event.WindowClosed) {
            const id = event.WindowClosed.id;
            windows = windows.filter(window => window.id !== id);
            if (focusedId === id) focusedId = null;
        } else if (event.WindowFocusChanged) {
            focusedId = event.WindowFocusChanged.id;
        } else if (event.WindowFocusTimestampChanged) {
            const change = event.WindowFocusTimestampChanged;
            windows = windows.map(window => window.id === change.id
                ? Object.assign({}, window, { focus_timestamp: change.focus_timestamp })
                : window);
        } else {
            return;
        }
        syncApps();
    }

    function appKey(window) {
        if (!window.app_id) return "window:" + window.id;
        const id = window.app_id.toLowerCase().replace(/\.desktop$/, "");
        const pin = pinnedApps.find(app => app.appId.toLowerCase() === id);
        if (pin) return pin.appId.toLowerCase();
        const entry = DesktopEntries.heuristicLookup(window.app_id);
        return entry ? entry.id.toLowerCase().replace(/\.desktop$/, "") : id;
    }

    function appIcon(entry, appId) {
        const icon = entry?.icon || appId;
        if (icon?.startsWith("/")) return "file://" + icon;
        return (icon && Quickshell.iconPath(icon, true))
            || Quickshell.iconPath("application-x-executable");
    }

    // Update rows in place so a focus or title event doesn't recreate hovered buttons.
    function syncApps() {
        const grouped = new Map();
        for (const window of windows) {
            const key = appKey(window);
            if (!grouped.has(key)) grouped.set(key, []);
            grouped.get(key).push(window);
        }

        const items = pinnedApps.map(app => {
            const entry = DesktopEntries.byId(app.desktopId);
            return {
                key: app.appId.toLowerCase(),
                displayName: app.name,
                iconSource: app.icon ? Quickshell.shellPath("icons/mac-tahoe/dock/" + app.icon) : appIcon(entry, app.appId),
                desktopId: app.desktopId
            };
        });
        const pinnedKeys = new Set(items.map(app => app.key));
        for (const [key, group] of grouped) {
            if (pinnedKeys.has(key)) continue;
            const window = group[0];
            const entry = window.app_id ? DesktopEntries.heuristicLookup(window.app_id) : null;
            items.push({
                key,
                displayName: entry?.name || window.app_id || window.title || "Window",
                iconSource: appIcon(entry, window.app_id),
                desktopId: entry?.id || ""
            });
        }

        let row = 0;
        for (const app of items) {
            const group = grouped.get(app.key) || [];
            const focused = group.find(window => window.id === focusedId);
            const recent = group.reduce((latest, window) => {
                const time = window.focus_timestamp;
                const last = latest?.focus_timestamp;
                if (!latest || (time && (!last || time.secs > last.secs
                    || (time.secs === last.secs && time.nanos > last.nanos)))) return window;
                return latest;
            }, null);
            const data = Object.assign({}, app, {
                windowCount: group.length,
                active: Boolean(focused),
                pinned: pinnedKeys.has(app.key),
                targetId: String((focused || recent)?.id ?? ""),
                startsRecent: row === pinnedApps.length && row > 0
            });
            let existing = row;
            while (existing < apps.count && apps.get(existing).key !== app.key) ++existing;
            if (existing === apps.count) {
                apps.insert(row, data);
            } else {
                if (existing !== row) apps.move(existing, row, 1);
                apps.set(row, data);
            }
            ++row;
        }
        if (apps.count > row) apps.remove(row, apps.count - row);
    }

    onPinnedAppsChanged: syncApps()

    ListModel { id: apps }

    Timer {
        id: hideTimer
        interval: 60
        onTriggered: if (!pointerArea.hovered) dock.edgeShown = false
    }

    Item {
        id: pointerArea
        readonly property bool hovered: dockHover.hovered
        readonly property int bottomInset: dock.overviewOpen ? dock.bottomGap : 0
        width: apps.count ? tray.width : 0
        height: dock.shown ? tray.height + dock.bottomGap - bottomInset : 4
        x: Math.round((parent.width - width) / 2)
        y: parent.height - height - bottomInset

        HoverHandler {
            id: dockHover
            blocking: false
            onHoveredChanged: {
                if (dock.overviewOpen) return;
                if (hovered) {
                    hideTimer.stop();
                    dock.edgeShown = true;
                } else if (dock.edgeShown) {
                    hideTimer.restart();
                }
            }
        }

        Rectangle {
            id: tray
            y: parent.height - height - dock.bottomGap + pointerArea.bottomInset
            width: appRow.implicitWidth + 12
            height: 48
            radius: dock.theme.radiusCard
            color: dock.theme.dock
            visible: apps.count > 0
            enabled: dock.shown

            transform: Translate {
                y: dock.shown ? 0 : tray.height + dock.bottomGap
                Behavior on y {
                    enabled: !dock.overviewOpen && !dock.reduceMotion
                    NumberAnimation {
                        duration: dock.shown ? 150 : 100
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Row {
                id: appRow
                anchors.centerIn: parent
                spacing: 3

                Repeater {
                    model: apps

                    Item {
                        id: tile
                        required property string key
                        required property bool pinned
                        required property string displayName
                        required property string iconSource
                        required property string desktopId
                        required property string targetId
                        required property int windowCount
                        required property bool active
                        required property bool startsRecent
                        width: dock.tileWidth + (startsRecent ? 10 : 0)
                        height: 44
                        z: tileHover.hovered ? 1 : 0

                        Rectangle {
                            visible: tile.startsRecent
                            x: 3
                            anchors.verticalCenter: parent.verticalCenter
                            width: 1
                            height: 22
                            color: dock.theme.outline
                        }

                        Item {
                            id: button
                            readonly property bool iconRaised: dock.shown && !dock.reduceMotion
                                && (tileHover.hovered || pin.hovered)
                            anchors.right: parent.right
                            width: dock.tileWidth
                            height: parent.height

                            Image {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 2
                                width: Math.min(34, button.width - 4)
                                height: width
                                fillMode: Image.PreserveAspectFit
                                source: tile.iconSource
                                sourceSize.width: 72
                                sourceSize.height: 72
                                transformOrigin: Item.Bottom
                                scale: button.iconRaised ? 1.06 : 1

                                Behavior on scale {
                                    enabled: !dock.reduceMotion
                                    NumberAnimation {
                                        duration: button.iconRaised ? 150 : 100
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                transform: [
                                    Translate {
                                        y: button.iconRaised ? -6 : 0
                                        Behavior on y {
                                            enabled: !dock.reduceMotion
                                            NumberAnimation {
                                                duration: button.iconRaised ? 150 : 100
                                                easing.type: Easing.OutCubic
                                            }
                                        }
                                    },
                                    Translate {
                                        id: launchLift
                                    }
                                ]
                            }

                            SequentialAnimation {
                                id: launchBounce
                                NumberAnimation {
                                    target: launchLift
                                    property: "y"
                                    to: -12
                                    duration: 100
                                    easing.type: Easing.OutCubic
                                }
                                NumberAnimation {
                                    target: launchLift
                                    property: "y"
                                    to: 0
                                    duration: 180
                                    easing.type: Easing.OutBounce
                                }
                            }

                            Rectangle {
                                visible: tile.windowCount > 0
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 3
                                width: tile.active ? 13 : 4
                                height: 3
                                radius: 2
                                color: tile.active ? dock.theme.ink : dock.theme.muted
                            }

                            HoverHandler {
                                id: tileHover
                                blocking: false
                                cursorShape: Qt.PointingHandCursor
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            }

                            TapHandler {
                                onTapped: {
                                    if (pin.hovered) return;
                                    if (tile.targetId) {
                                        Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", tile.targetId]);
                                    } else if (tile.desktopId) {
                                        Quickshell.execDetached(["gtk-launch", tile.desktopId]);
                                        if (!dock.reduceMotion && !launchBounce.running)
                                            launchBounce.start();
                                    }
                                }
                            }

                            Button {
                                id: pin
                                anchors.top: parent.top
                                anchors.right: parent.right
                                width: 19
                                height: 19
                                padding: 0
                                hoverEnabled: true
                                visible: dock.shown && (tileHover.hovered || hovered || activeFocus)
                                    && (tile.pinned || tile.desktopId !== "")
                                Accessible.name: (tile.pinned ? "Unpin " : "Pin ") + tile.displayName
                                onClicked: dock.pinRequested(tile.key, tile.desktopId, tile.displayName)
                                background: Rectangle {
                                    radius: width / 2
                                    color: pin.hovered || pin.visualFocus ? dock.theme.selected : dock.theme.card
                                    border.color: dock.theme.line
                                }
                                contentItem: Text {
                                    text: tile.pinned ? "−" : "+"
                                    color: dock.theme.ink
                                    font.pixelSize: 14
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            Rectangle {
                                visible: (tileHover.hovered || pin.hovered) && dock.shown
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.top
                                anchors.bottomMargin: 9
                                width: caption.implicitWidth + 14
                                height: 20
                                radius: dock.theme.radiusControl
                                color: dock.theme.surface

                                Text {
                                    id: caption
                                    anchors.centerIn: parent
                                    text: pin.hovered ? (tile.pinned ? "Unpin from Dock" : "Pin to Dock")
                                        : tile.windowCount > 1
                                        ? tile.displayName + " · " + tile.windowCount + " windows"
                                        : tile.displayName
                                    color: dock.theme.ink
                                    font.family: dock.labelFont
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
