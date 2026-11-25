import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: spotlight

    required property RiceTheme theme

    required property string face
    required property var windows
    required property var utilities
    property var fileResults: []
    property string mode: ""
    property var actionTarget: null
    property var favorites: []
    property var recentEmoji: []
    // Recents as they were when the picker opened, so picking doesn't reshuffle the grid.
    property var shownRecentEmoji: []
    property var emojiQueue: []
    property bool lendingKeyboard: false
    property var emojis: []
    property bool stateReady: false
    property int selectedIndex: 0
    readonly property string query: search.text.trim()
    readonly property var results: {
        if (mode === "windows") return windowResults(query);
        if (mode === "files") return fileResults;
        if (mode === "emoji") return emojiResults(query);
        if (!query) return homeResults();
        return applicationResults(query).concat(fileResults);
    }
    readonly property var selectedResult: results[selectedIndex] ?? null
    readonly property var actions: actionTarget ? actionsFor(actionTarget) : []
    readonly property var visibleActions: actions.filter(action => action.name.toLowerCase().includes(actionSearch.text.trim().toLowerCase()))
    readonly property var rows: actionTarget ? visibleActions : results
    readonly property int rowHeight: 44
    readonly property bool emojiMode: mode === "emoji"
    readonly property bool searchesFiles: mode === "" || mode === "files"
    readonly property int emojiColumns: 10
    readonly property int emojiCellHeight: 48

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "rice-spotlight"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: lendingKeyboard ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
    color: "transparent"
    visible: false

    readonly property var commands: [
        { name: "Search Files", location: "Command", command: "files", icon: "system-search" },
        { name: "Switch Windows", location: "Command", command: "windows", icon: "preferences-system-windows" },
        { name: "Emoji", location: "Command", command: "emoji", icon: "face-smile" },
        { name: "Clipboard History", location: "Command", utility: "clipboard", icon: "edit-paste" },
        { name: "Wallpapers", location: "Command", utility: "wallpaper", icon: "preferences-desktop-wallpaper" },
        { name: "Power", location: "Command", utility: "power", icon: "system-shutdown" }
    ]

    FileView {
        id: savedState
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/rice-spotlight.json"
        preload: true
        printErrors: false
        atomicWrites: true
        blockWrites: true
        onLoaded: {
            if (spotlight.stateReady) return;
            try {
                const data = JSON.parse(text());
                spotlight.favorites = Array.isArray(data.favorites) ? data.favorites.filter(id => typeof id === "string") : [];
                spotlight.recentEmoji = Array.isArray(data.recentEmoji) ? data.recentEmoji.filter(char => typeof char === "string") : [];
            } catch (error) {
                console.warn("Could not read Spotlight preferences:", error);
            }
            spotlight.stateReady = true;
        }
        onLoadFailed: spotlight.stateReady = true
    }

    function saveState() {
        savedState.setText(JSON.stringify({ favorites, recentEmoji }));
    }

    // Rows are [emoji, name, space-separated keywords], in Unicode's picker order.
    FileView {
        path: Quickshell.shellPath("emojis.json")
        preload: true
        onLoaded: {
            try {
                spotlight.emojis = JSON.parse(text()).map(([emoji, name, keywords]) => ({ emoji, name, keywords }));
            } catch (error) {
                console.warn("Could not read emoji list:", error);
            }
        }
    }

    // Lower ranks sort first: whole words, then word prefixes, then loose text matches.
    function emojiRank(entry, term, words) {
        if (entry.name === term) return 0;
        const name = " " + entry.name + " ";
        const keywords = " " + entry.keywords + " ";
        if (name.includes(" " + term + " ") || keywords.includes(" " + term + " ")) return 1;
        if (name.includes(" " + term)) return 2;
        if (keywords.includes(" " + term)) return 3;
        const details = name + keywords;
        return words.every(word => details.includes(word)) ? 4 : Infinity;
    }

    // With no query, recently used emoji lead the grid.
    function emojiResults(query) {
        const term = query.toLowerCase();
        if (!term) {
            const recent = shownRecentEmoji.map(char => emojis.find(entry => entry.emoji === char)).filter(Boolean);
            return recent.concat(emojis.filter(entry => !shownRecentEmoji.includes(entry.emoji)));
        }
        const words = term.split(/\s+/);
        return emojis.map(entry => ({ entry, rank: emojiRank(entry, term, words) }))
            .filter(item => Number.isFinite(item.rank))
            .sort((a, b) => a.rank - b.rank)
            .map(item => item.entry);
    }

    // Inserts into the app behind the picker, which stays open for more picks.
    function insertEmoji(char) {
        emojiQueue = emojiQueue.concat(char);
        insertNext();
        recentEmoji = [char].concat(recentEmoji.filter(entry => entry !== char)).slice(0, emojiColumns * 2);
        saveState();
    }

    // One insert at a time, because each one borrows the keyboard and the clipboard.
    function insertNext() {
        if (inserter.running || !emojiQueue.length) return;
        const [char, ...rest] = emojiQueue;
        emojiQueue = rest;
        lendingKeyboard = true;
        inserter.command = ["sh", Quickshell.shellPath("insert-emoji.sh"), char];
        inserter.running = true;
    }

    // The script prints a line once its paste is sent, so the keyboard can come back
    // before it finishes restoring the clipboard. Typed inserts just exit.
    Process {
        id: inserter
        stdout: SplitParser {
            onRead: spotlight.lendingKeyboard = false
        }
        onExited: {
            spotlight.lendingKeyboard = false;
            Qt.callLater(spotlight.insertNext);
        }
    }

    function openMode(name) {
        if (name === "emoji") shownRecentEmoji = recentEmoji;
        closeActions();
        mode = name;
        search.clear();
        resetSearch();
        search.forceActiveFocus();
    }

    function appResult(app, location) {
        return { name: app.name, location, app };
    }

    function homeResults() {
        const pinned = favorites.map(id => DesktopEntries.byId(id)).filter(Boolean)
            .map(app => appResult(app, "Favorite"));
        return pinned.concat(commands);
    }

    // Exact matches win, then prefixes, word initials and fuzzy subsequences.
    function matchScore(value, term) {
        const label = value.toLowerCase();
        const compactTerm = term.replace(/\s+/g, "");
        if (label === term) return 0;
        if (label.startsWith(term)) return 10;
        const initials = label.split(/[^\p{L}\p{N}]+/u).filter(Boolean).map(word => word[0]).join("");
        if (initials.startsWith(compactTerm)) return 20;
        const position = label.indexOf(term);
        if (position >= 0) return 30 + Math.min(10, position);
        let at = 0;
        let first = -1;
        for (let i = 0; i < label.length; i++) {
            if (label[i] !== compactTerm[at]) continue;
            if (first < 0) first = i;
            if (++at === compactTerm.length) {
                const gaps = i - first + 1 - at;
                return 50 + Math.min(30, first / 2 + gaps);
            }
        }
        return Infinity;
    }

    function applicationResults(query) {
        const term = query.toLowerCase();
        const words = term.split(/\s+/);
        const matches = commands.map(command => ({
            result: command, rank: matchScore(command.name, term), priority: 0
        }));
        for (const app of DesktopEntries.applications.values) {
            const details = [app.name, app.id, app.genericName].concat(Array.from(app.keywords)).join(" ").toLowerCase();
            const rank = Math.min(matchScore(app.name, term), words.every(word => details.includes(word)) ? 85 : Infinity);
            if (!Number.isFinite(rank)) continue;
            const priority = favorites.includes(app.id) ? 0 : 1;
            matches.push({ result: appResult(app, "Application"), rank, priority });
        }
        return matches.filter(item => Number.isFinite(item.rank))
            .sort((a, b) => a.rank - b.rank || a.priority - b.priority || a.result.name.localeCompare(b.result.name))
            .slice(0, 12).map(item => item.result);
    }

    function windowResults(query) {
        const term = query.toLowerCase();
        return windows.map(window => {
            const app = window.app_id ? DesktopEntries.heuristicLookup(window.app_id) : null;
            const name = window.title || app?.name || window.app_id || "Window";
            const location = app?.name || window.app_id || "";
            return {
                name, location, app, windowId: window.id,
                rank: term ? Math.min(matchScore(name, term), matchScore(location, term)) : 0,
                time: window.focus_timestamp?.secs ?? 0,
                nanos: window.focus_timestamp?.nanos ?? 0
            };
        }).filter(window => Number.isFinite(window.rank))
            .sort((a, b) => a.rank - b.rank || b.time - a.time || b.nanos - a.nanos);
    }

    function runResult(result) {
        if (!result) return;
        if (result.utility) {
            visible = false;
            utilities.toggle(result.utility);
            return;
        }
        if (result.command) {
            openMode(result.command);
            return;
        }
        if (result.emoji) {
            insertEmoji(result.emoji);
            return;
        }
        visible = false;
        if (result.windowId !== undefined) {
            Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", String(result.windowId)]);
        } else if (result.app) {
            Quickshell.execDetached(["gtk-launch", result.app.id]);
        } else {
            Quickshell.execDetached(["xdg-open", result.url]);
        }
    }

    function actionsFor(result) {
        const list = [{
            name: result.command || result.utility ? "Run command" : result.windowId !== undefined ? "Focus window" : "Open",
            icon: "go-next", run: () => runResult(result)
        }];
        if (result.windowId !== undefined || result.command || result.utility) return list;
        if (result.app) {
            const id = result.app.id;
            const pinned = favorites.includes(id);
            list.push({ name: pinned ? "Remove from Favorites" : "Add to Favorites", icon: "starred", run: () => {
                favorites = pinned ? favorites.filter(entry => entry !== id) : favorites.concat(id);
                saveState();
                closeActions();
                selectedIndex = Math.min(selectedIndex, Math.max(0, results.length - 1));
            } });
            for (const desktopAction of result.app.actions) {
                list.push({ name: desktopAction.name, icon: desktopAction.icon || "go-next", run: () => {
                    visible = false;
                    desktopAction.execute();
                } });
            }
        } else {
            list.push({ name: "Reveal in Files", icon: "folder", run: () => {
                visible = false;
                Quickshell.execDetached(["rice-files", "--select", result.url]);
            } });
            list.push({ name: "Copy path", icon: "edit-copy", run: () => {
                Quickshell.clipboardText = decodeURIComponent(result.url.slice(7));
                visible = false;
            } });
        }
        return list;
    }

    function toggleActions() {
        if (actionTarget) {
            closeActions();
        } else if (selectedResult && !emojiMode) {
            actionTarget = selectedResult;
            actionSearch.clear();
            actionList.currentIndex = 0;
            actionSearch.forceActiveFocus();
        }
    }

    function closeActions() {
        if (!actionTarget) return;
        actionTarget = null;
        if (visible) search.forceActiveFocus();
    }

    function moveSelection(delta) {
        if (!rows.length) return;
        if (actionTarget) {
            actionList.currentIndex = (actionList.currentIndex + delta + rows.length) % rows.length;
            actionList.positionViewAtIndex(actionList.currentIndex, ListView.Contain);
        } else {
            selectedIndex = (selectedIndex + delta + rows.length) % rows.length;
            if (emojiMode) emojiGrid.positionViewAtIndex(selectedIndex, GridView.Contain);
            else resultList.positionViewAtIndex(selectedIndex, ListView.Contain);
        }
    }

    // Vertical movement stops at the grid's edges. A short last row selects its last emoji.
    function moveEmojiRow(delta) {
        const next = selectedIndex + delta * emojiColumns;
        const lastRow = Math.floor((rows.length - 1) / emojiColumns);
        if (next < 0 || Math.floor(next / emojiColumns) > lastRow) return;
        selectedIndex = Math.min(next, rows.length - 1);
        emojiGrid.positionViewAtIndex(selectedIndex, GridView.Contain);
    }

    function handleKey(event) {
        const control = (event.modifiers & Qt.ControlModifier) !== 0;
        if (control && event.key === Qt.Key_K) {
            toggleActions();
        } else if (event.key === Qt.Key_Escape) {
            if (actionTarget) closeActions();
            else if (query) search.clear();
            else if (mode) {
                mode = "";
                resetSearch();
            } else visible = false;
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
            const step = event.key === Qt.Key_Up ? -1 : 1;
            if (emojiMode) moveEmojiRow(step);
            else moveSelection(step);
        } else if (emojiMode && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
            moveSelection(event.key === Qt.Key_Left ? -1 : 1);
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (actionTarget) visibleActions[actionList.currentIndex]?.run();
            else if (control && selectedResult && !emojiMode) actionsFor(selectedResult)[1]?.run();
            else runResult(selectedResult);
        } else {
            return;
        }
        event.accepted = true;
    }

    function resetSearch() {
        selectedIndex = 0;
        fileResults = [];
        resultList.positionViewAtBeginning();
        emojiGrid.positionViewAtBeginning();
        if (visible && searchesFiles && query.length >= 3) fileDelay.restart();
        else fileDelay.stop();
    }

    onVisibleChanged: {
        if (visible) {
            Qt.callLater(() => { if (visible) search.forceActiveFocus(); });
        } else {
            closeActions();
            mode = "";
            search.clear();
            resetSearch();
        }
    }

    onQueryChanged: resetSearch()

    IpcHandler {
        target: "spotlight"
        function toggle(): void { spotlight.visible = !spotlight.visible; }

        // Closes the picker if it's already open, otherwise opens or switches to it.
        function emoji(): void {
            if (spotlight.visible && spotlight.emojiMode) {
                spotlight.visible = false;
                return;
            }
            spotlight.visible = true;
            spotlight.openMode("emoji");
        }
    }

    Timer {
        id: fileDelay
        interval: 180
        onTriggered: {
            if (fileReader.running) {
                restart();
                return;
            }
            fileReader.command = ["python3", Quickshell.shellPath("spotlight-files.py"), spotlight.query];
            fileReader.running = true;
        }
    }

    Process {
        id: fileReader
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim()) return;
                try {
                    const result = JSON.parse(text);
                    if (spotlight.visible && spotlight.searchesFiles && result.query === spotlight.query)
                        spotlight.fileResults = result.matches;
                } catch (error) {
                    console.warn("Could not read Spotlight file results:", error);
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#28000000"

        TapHandler { onTapped: spotlight.visible = false }
    }

    Rectangle {
        id: surface
        width: Math.min(540, parent.width - 32)
        // The picker keeps a fixed height so it doesn't jump while filtering.
        readonly property int bodyHeight: spotlight.emojiMode ? spotlight.emojiCellHeight * 6
            : Math.max(44, Math.min(spotlight.rows.length, 7) * spotlight.rowHeight)
        height: search.height + bodyHeight + footer.height + 10
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.22)
        radius: spotlight.theme.radiusPanel
        color: spotlight.theme.surface
        border.color: spotlight.theme.line

        // Keep clicks on the search surface separate from the backdrop.
        MouseArea { anchors.fill: parent }

        Item {
            width: 30
            height: search.height
            x: 12

            Rectangle {
                x: 7
                y: 18
                width: 14
                height: 14
                radius: 7
                color: "transparent"
                border.color: spotlight.theme.secondary
                border.width: 2
            }

            Rectangle {
                x: 17
                y: 31
                width: 9
                height: 2
                radius: 1
                rotation: 45
                color: spotlight.theme.secondary
            }
        }

        TextField {
            id: search
            anchors.left: parent.left
            anchors.leftMargin: 43
            anchors.right: parent.right
            anchors.rightMargin: 12
            height: 52
            visible: spotlight.actionTarget === null
            placeholderText: spotlight.emojiMode ? "Search emoji"
                : spotlight.mode === "windows" ? "Search open windows"
                : spotlight.mode === "files" ? "Search files" : "Search apps, files, and commands"
            Accessible.name: placeholderText
            font.family: spotlight.face
            font.pixelSize: 21
            color: spotlight.theme.ink
            placeholderTextColor: spotlight.theme.muted
            selectionColor: spotlight.theme.accent
            selectedTextColor: "#ffffff"
            background: null
            focus: true
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: event => spotlight.handleKey(event)
        }

        TextField {
            id: actionSearch
            anchors.fill: search
            visible: spotlight.actionTarget !== null
            placeholderText: "Actions for " + (spotlight.actionTarget?.name ?? "")
            Accessible.name: placeholderText
            font: search.font
            color: search.color
            placeholderTextColor: search.placeholderTextColor
            selectionColor: search.selectionColor
            selectedTextColor: search.selectedTextColor
            background: null
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: event => spotlight.handleKey(event)
            onTextChanged: actionList.currentIndex = 0
        }

        Rectangle {
            anchors.top: search.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 8
            anchors.topMargin: 0
            height: 1
            color: spotlight.theme.line
        }

        RiceListView {
            id: resultList
            anchors.top: search.bottom
            anchors.topMargin: 5
            anchors.bottom: footer.top
            anchors.bottomMargin: 5
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            visible: !spotlight.emojiMode && !spotlight.actionTarget && count > 0
            clip: true
            focus: false
            keyNavigationEnabled: false
            currentIndex: spotlight.selectedIndex
            model: spotlight.emojiMode ? [] : spotlight.results

            delegate: Rectangle {
                id: row
                required property int index
                required property var modelData
                width: ListView.view.width
                height: spotlight.rowHeight
                radius: spotlight.theme.radiusControl
                color: index === spotlight.selectedIndex ? spotlight.theme.selected : hit.containsMouse ? spotlight.theme.tile : "transparent"

                Image {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 25
                    height: 25
                    source: {
                        const icon = row.modelData.app?.icon || row.modelData.icon || (row.modelData.folder ? "folder" : "text-x-generic");
                        return icon.startsWith("/") ? "file://" + icon : Quickshell.iconPath(icon);
                    }
                    fillMode: Image.PreserveAspectFit
                }

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 46
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        width: parent.width
                        text: row.modelData.name
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: spotlight.theme.ink
                        font.family: spotlight.face
                        font.pixelSize: 15
                    }
                    Text {
                        width: parent.width
                        text: row.modelData.location ?? ""
                        textFormat: Text.PlainText
                        elide: Text.ElideMiddle
                        color: spotlight.theme.muted
                        font.family: spotlight.face
                        font.pixelSize: 11
                    }
                }

                MouseArea {
                    id: hit
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: spotlight.runResult(row.modelData)
                }
            }
        }

        GridView {
            id: emojiGrid
            anchors.fill: resultList
            visible: spotlight.emojiMode && count > 0
            clip: true
            focus: false
            keyNavigationEnabled: false
            boundsBehavior: Flickable.StopAtBounds
            acceptedButtons: Qt.NoButton
            flickableDirection: Flickable.VerticalFlick
            cellWidth: width / spotlight.emojiColumns
            cellHeight: spotlight.emojiCellHeight
            currentIndex: spotlight.selectedIndex
            model: spotlight.emojiMode ? spotlight.results : []

            RiceTrackpadScroll { viewport: emojiGrid }

            delegate: Rectangle {
                id: cell
                required property int index
                required property var modelData
                width: GridView.view.cellWidth
                height: GridView.view.cellHeight
                radius: spotlight.theme.radiusControl
                color: index === spotlight.selectedIndex ? spotlight.theme.selected : cellHit.containsMouse ? spotlight.theme.tile : "transparent"
                Accessible.role: Accessible.Button
                Accessible.name: modelData.name

                Text {
                    anchors.centerIn: parent
                    text: cell.modelData.emoji ?? ""
                    textFormat: Text.PlainText
                    font.family: "Noto Color Emoji"
                    font.pixelSize: 26
                }

                MouseArea {
                    id: cellHit
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: spotlight.runResult(cell.modelData)
                }
            }
        }

        RiceListView {
            id: actionList
            anchors.fill: resultList
            visible: spotlight.actionTarget !== null
            clip: true
            keyNavigationEnabled: false
            model: spotlight.visibleActions

            delegate: Button {
                id: actionRow
                required property var modelData
                required property int index
                width: ListView.view.width
                height: spotlight.rowHeight
                hoverEnabled: true
                focusPolicy: Qt.NoFocus
                text: modelData.name
                onClicked: modelData.run()

                contentItem: Item {
                    implicitHeight: 24
                    Image {
                        id: actionIcon
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        height: 18
                        source: Quickshell.iconPath(actionRow.modelData.icon, true)
                        fillMode: Image.PreserveAspectFit
                    }
                    Text {
                        anchors.left: actionIcon.right
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: actionRow.text
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: spotlight.theme.ink
                        font.family: spotlight.face
                        font.pixelSize: 15
                    }
                }
                background: Rectangle {
                    radius: spotlight.theme.radiusControl
                    color: actionRow.index === actionList.currentIndex ? spotlight.theme.selected
                        : actionRow.hovered ? spotlight.theme.tile : "transparent"
                }
            }
        }

        Text {
            x: 17
            y: search.height + 15
            visible: spotlight.rows.length === 0
            text: {
                if (spotlight.actionTarget) return "No matching actions";
                if (spotlight.mode === "files" && spotlight.query.length < 3) return "Enter at least three characters";
                if (spotlight.searchesFiles && (fileDelay.running || fileReader.running)) return "Searching files…";
                return "No results";
            }
            color: spotlight.theme.muted
            font.family: spotlight.face
            font.pixelSize: 14
        }

        Rectangle {
            id: footer
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 32
            color: "transparent"

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 8
                anchors.topMargin: 0
                height: 1
                color: spotlight.theme.line
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: spotlight.emojiMode ? "↵  Insert     " + (spotlight.selectedResult?.name ?? "")
                    : spotlight.actionTarget ? "Esc  Back" : "↑ ↓  Select     ↵  Open"
                color: spotlight.theme.muted
                font.family: spotlight.face
                font.pixelSize: 12
            }

            Button {
                id: actionsButton
                anchors.right: parent.right
                anchors.rightMargin: 7
                anchors.verticalCenter: parent.verticalCenter
                height: 25
                visible: !spotlight.emojiMode && (spotlight.actionTarget !== null || spotlight.selectedResult !== null)
                text: spotlight.actionTarget ? "Ctrl+K  Close actions" : "Ctrl+K  Actions"
                focusPolicy: Qt.NoFocus
                onClicked: spotlight.toggleActions()
                contentItem: Text {
                    text: actionsButton.text
                    color: spotlight.theme.secondary
                    font.family: spotlight.face
                    font.pixelSize: 12
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: spotlight.theme.radiusSmall
                    color: actionsButton.hovered ? spotlight.theme.hover : "transparent"
                }
            }
        }
    }
}
