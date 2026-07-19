import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Window
import org.kde.kirigami as Kirigami
import org.kde.ksysguard.process as Process
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.plasmoid

Item {
    // exact fit

    id: root

    // row height mirrors the delegate formula
    readonly property int rowH: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing * 4
    readonly property int headerH: Math.ceil(Kirigami.Units.gridUnit * 1.8)
    readonly property int marginsH: Kirigami.Units.largeSpacing * 3 // top + bottom + gap
    // While the model is loading rows is empty; use a tall enough fallback
    // so Plasma never caches a 1-row height.  Once data arrives we snap to
    // the exact count.  minimumHeight == preferredHeight forces Plasma to
    // always respect this value even if it has a stale cached size.
    readonly property int popupHeight: {
        if (rows.length === 0)
            return Kirigami.Units.gridUnit * 20;

        // loading fallback
        var baseH = marginsH + headerH + rows.length * rowH;
        if (root.uptimeDisplayMode === 2 && root.systemUptimeStr !== "")
            baseH += Kirigami.Units.gridUnit * 1.5;

        return baseH;
    }
    readonly property int colName: 0
    readonly property int colIcon: 1
    readonly property int colCpu: 2
    readonly property int colMem: 3
    readonly property int cpuCoreCount: 16
    // Adjust these widths to your preference
    property int nameWidth: 300
    property int cpuWidth: 80
    property int memWidth: 100 // back to normal (no debug)
    readonly property bool isWindowVisible: root.Window.window ? root.Window.window.visible : false
    property string sortColumn: "cpu"
    property bool sortAscending: false
    property var rows: []
    property bool firstUpdatePending: false
    property string systemUptimeStr: ""
    readonly property int uptimeDisplayMode: {
        var val = Plasmoid.configuration.systemUptimeDisplay;
        return (val === undefined) ? 2 : val;
    }

    function parseMemoryBytes(str) {
        if (!str)
            return 0;

        var s = String(str).trim();
        var match = s.match(/^([\d.]+)\s*([A-Za-z]+)?/);
        if (!match)
            return 0;

        var num = parseFloat(match[1]);
        if (isNaN(num))
            return 0;

        var unit = (match[2] || "b").toLowerCase();
        var multiplier = 1;
        if (unit.indexOf("t") >= 0)
            multiplier = 1e+12;
        else if (unit.indexOf("g") >= 0)
            multiplier = 1e+09;
        else if (unit.indexOf("m") >= 0)
            multiplier = 1e+06;
        else if (unit.indexOf("k") >= 0)
            multiplier = 1000;
        return num * multiplier;
    }

    function parseLeadingNumber(str) {
        if (!str)
            return 0;

        var cleaned = String(str).replace(/[^0-9.-]/g, '');
        return parseFloat(cleaned) || 0;
    }

    function formatUptime(seconds) {
        var s = Math.floor(seconds);
        if (s < 60)
            return s + "s";

        var m = Math.floor(s / 60);
        s = s % 60;
        if (m < 60)
            return m + "m " + s + "s";

        var h = Math.floor(m / 60);
        m = m % 60;
        if (h < 24)
            return h + "h " + m + "m";

        var d = Math.floor(h / 24);
        h = h % 24;
        return d + "d " + h + "h";
    }

    function rebuildRows() {
        if (root.uptimeDisplayMode !== 0)
            uptimeSource.fetchUptime();
        else
            root.systemUptimeStr = "";
        var out = [];
        var n = appModel.rowCount();
        for (var i = 0; i < n; i++) {
            var nameIdx = appModel.index(i, root.colName);
            var iconIdx = appModel.index(i, root.colIcon);
            var cpuIdx = appModel.index(i, root.colCpu);
            var memIdx = appModel.index(i, root.colMem);
            var appName = String(appModel.data(nameIdx, Process.ProcessDataModel.Value) || "");
            var iconName = String(appModel.data(iconIdx, Process.ProcessDataModel.Value) || "application-x-executable");
            var cpuRaw = String(appModel.data(cpuIdx, Process.ProcessDataModel.FormattedValue) || "0.0 %");
            var memFmt = String(appModel.data(memIdx, Process.ProcessDataModel.FormattedValue) || "–");
            var pids = appModel.data(nameIdx, Process.ProcessDataModel.PIDs) || [];
            var rawVal = root.parseLeadingNumber(cpuRaw);
            var scaledVal = rawVal / root.cpuCoreCount;
            if (isNaN(scaledVal) || !isFinite(scaledVal))
                scaledVal = 0;

            out.push({
                "appName": appName,
                "iconName": iconName,
                "cpuFmt": scaledVal.toFixed(1) + "%",
                "cpuRaw": rawVal,
                "memFmt": memFmt,
                "memVal": root.parseMemoryBytes(memFmt),
                "pids": pids
            });
        }
        out.sort(function(a, b) {
            var res = 0;
            if (root.sortColumn === "name")
                res = a.appName.localeCompare(b.appName);
            else if (root.sortColumn === "cpu")
                res = a.cpuRaw - b.cpuRaw;
            else if (root.sortColumn === "mem")
                res = a.memVal - b.memVal;
            return root.sortAscending ? res : -res;
        });
        root.rows = out;
    }

    Layout.preferredWidth: Kirigami.Units.gridUnit * 32
    Layout.minimumWidth: Kirigami.Units.gridUnit * 24
    Layout.preferredHeight: popupHeight
    Layout.minimumHeight: popupHeight
    Layout.maximumHeight: popupHeight
    onIsWindowVisibleChanged: {
        if (isWindowVisible) {
            firstUpdatePending = true;
            firstUpdateTimer.restart();
        }
    }
    onSortColumnChanged: rebuildRows()
    onSortAscendingChanged: rebuildRows()

    Timer {
        id: firstUpdateTimer

        interval: 150
        running: false
        repeat: false
        onTriggered: root.rebuildRows()
    }

    Process.ApplicationDataModel {
        id: appModel

        enabledAttributes: ["appName", "iconName", "usage", "memory"]
        enabled: root.Window.window ? root.Window.window.visible : false
        cgroupMapping: {
            "session.slice": "services",
            "background.slice": "services",
            "org.a11y.atspi.Registry": "services",
            "org.kde.discover.notifier": "services",
            "geoclue": "services",
            "org.kde.kunifiedpush": "services",
            "dconf.service": "services",
            "flatpak-session-helper.service": "services",
            "gpg-agent.service": "services",
            "org.kde.xwaylandvideobridge": "services",
            "org.kde.kalendarac": "services",
            "xdg-desktop-portal-gtk.service": "services",
            "org.kde.kdeconnect": "services",
            "org.kde.kwalletd6": "services",
            "org.kde.kclockd": "services"
        }
        applicationOverrides: {
            "services": {
                "appName": i18nc("@label", "Background Services"),
                "iconName": "preferences-system-services"
            }
        }
        Component.onCompleted: root.rebuildRows()
        onModelReset: {
            if (Plasmoid.expanded)
                debounceTimer.restart();

        }
        onRowsInserted: {
            if (Plasmoid.expanded)
                debounceTimer.restart();

        }
        onRowsRemoved: {
            if (Plasmoid.expanded)
                debounceTimer.restart();

        }
        onDataChanged: {
            if (root.firstUpdatePending) {
                root.firstUpdatePending = false;
                firstUpdateTimer.restart();
            }
            if (Plasmoid.expanded)
                debounceTimer.restart();

        }
    }

    Timer {
        id: debounceTimer

        interval: 200
        running: false
        repeat: false
        onTriggered: root.rebuildRows()
    }

    Timer {
        interval: Math.max(1000, Plasmoid.configuration.refreshInterval * 1000)
        running: root.Window.window ? root.Window.window.visible : false
        repeat: true
        triggeredOnStart: false
        onTriggered: root.rebuildRows()
    }

    Process.ProcessController {
        id: processController

        window: root.Window.window
    }

    Plasma5Support.DataSource {
        id: uptimeSource

        function fetchUptime() {
            connectSource("cat /proc/uptime");
        }

        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            disconnectSource(source);
            var stdout = data["stdout"] || "";
            var uptimeSec = parseFloat(stdout.trim().split(" ")[0]) || 0;
            if (uptimeSec > 0)
                root.systemUptimeStr = root.formatUptime(uptimeSec);

        }
    }

    // ---------- UI ----------
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        RowLayout {
            spacing: Kirigami.Units.smallSpacing
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 1.8
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing

            Item {
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }

            SortHeader {
                id: nameHeader

                Layout.fillWidth: true
                label: i18n("Name")
                col: "name"
                alignment: Qt.AlignLeft
                extraText: (root.uptimeDisplayMode === 1 && root.systemUptimeStr !== "") ? i18n("Uptime: %1", root.systemUptimeStr) : ""
                onSortClicked: {
                    if (root.sortColumn === "name") {
                        root.sortAscending = !root.sortAscending;
                    } else {
                        root.sortColumn = "name";
                        root.sortAscending = false;
                    }
                }
            }

            SortHeader {
                Layout.preferredWidth: root.cpuWidth
                label: i18n("CPU")
                col: "cpu"
                alignment: Qt.AlignRight
                onSortClicked: {
                    if (root.sortColumn === "cpu") {
                        root.sortAscending = !root.sortAscending;
                    } else {
                        root.sortColumn = "cpu";
                        root.sortAscending = false;
                    }
                }
            }

            SortHeader {
                Layout.preferredWidth: root.memWidth
                label: i18n("Memory")
                col: "mem"
                alignment: Qt.AlignRight
                onSortClicked: {
                    if (root.sortColumn === "mem") {
                        root.sortAscending = !root.sortAscending;
                    } else {
                        root.sortColumn = "mem";
                        root.sortAscending = false;
                    }
                }
            }

            Item {
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }

        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            ListView {
                id: listView

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.rows
                spacing: 0

                Kirigami.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - Kirigami.Units.gridUnit * 4
                    visible: root.rows.length === 0
                    icon.name: "application-x-executable"
                    text: i18n("No running applications found")
                }

                delegate: Item {
                    id: delegateRoot

                    width: listView.width
                    height: Math.max(Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing * 4, row.implicitHeight)

                    HoverHandler {
                        id: delegateHover
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: 2
                        anchors.rightMargin: 2
                        color: Kirigami.Theme.highlightColor
                        opacity: delegateHover.hovered ? 0.08 : 0
                        radius: 4

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 100
                            }

                        }

                    }

                    RowLayout {
                        id: row

                        anchors.fill: parent
                        anchors.leftMargin: Kirigami.Units.smallSpacing * 2
                        anchors.rightMargin: Kirigami.Units.smallSpacing * 2
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            source: modelData.iconName
                        }

                        QQC2.Label {
                            Layout.fillWidth: true
                            text: modelData.appName || i18n("Unknown")
                            elide: Text.ElideRight
                            font.weight: Font.Medium
                        }

                        QQC2.Label {
                            Layout.preferredWidth: root.cpuWidth
                            text: modelData.cpuFmt
                            horizontalAlignment: Text.AlignRight
                            font.features: {
                                "tnum": 1
                            }
                        }

                        QQC2.Label {
                            Layout.preferredWidth: root.memWidth
                            text: modelData.memFmt
                            horizontalAlignment: Text.AlignRight
                            font.features: {
                                "tnum": 1
                            }
                        }

                        QQC2.ToolButton {
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium + Kirigami.Units.smallSpacing * 2
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium + Kirigami.Units.smallSpacing * 2
                            icon.width: Kirigami.Units.iconSizes.smallMedium
                            icon.height: Kirigami.Units.iconSizes.smallMedium
                            icon.name: "process-stop"
                            display: QQC2.AbstractButton.IconOnly
                            text: i18n("Kill process")
                            enabled: modelData.pids && modelData.pids.length > 0
                            QQC2.ToolTip.text: i18n("Kill process")
                            QQC2.ToolTip.visible: hovered
                            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                            onClicked: {
                                if (modelData.pids && modelData.pids.length > 0) {
                                    killDialog.pids = modelData.pids;
                                    killDialog.open();
                                }
                            }
                        }

                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        color: Kirigami.Theme.textColor
                        opacity: 0.15
                    }

                }

            }

            QQC2.ScrollBar {
                id: vertScrollBar

                Layout.fillHeight: true
                orientation: Qt.Vertical
                size: listView.visibleArea.heightRatio
                position: listView.visibleArea.yPosition
                active: listView.moving || vertScrollBar.hovered || vertScrollBar.pressed
                policy: QQC2.ScrollBar.AsNeeded
                onPositionChanged: {
                    if (active)
                        listView.contentY = position * listView.contentHeight;

                }
            }

        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.uptimeDisplayMode === 2 && root.systemUptimeStr !== ""
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: i18n("System Uptime: %1", root.systemUptimeStr)
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.9
                font.italic: true
                color: Kirigami.Theme.textColor
                opacity: 0.8
            }

        }

    }

    Kirigami.PromptDialog {
        id: killDialog

        property var pids: []

        title: i18n("Kill Process?")
        subtitle: i18n("Are you sure you want to terminate this process?")
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        onAccepted: {
            if (pids && pids.length > 0)
                processController.sendSignal(pids, 9);

        }
    }

    component SortHeader: Item {
        property string label: ""
        property string col: ""
        property int alignment: Qt.AlignLeft
        property string extraText: ""

        signal sortClicked()

        implicitHeight: Kirigami.Units.gridUnit * 1.8

        Rectangle {
            anchors.fill: parent
            color: Kirigami.Theme.highlightColor
            opacity: mouseArea.containsMouse ? 0.12 : 0
            radius: 4

            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                }

            }

        }

        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: alignment === Qt.AlignLeft ? Kirigami.Units.smallSpacing * 2 : 0
            anchors.rightMargin: alignment === Qt.AlignRight ? Kirigami.Units.smallSpacing * 2 : 0
            spacing: Kirigami.Units.smallSpacing

            Item {
                Layout.fillWidth: true
                visible: alignment === Qt.AlignRight
            }

            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                Layout.alignment: alignment

                QQC2.Label {
                    text: label
                    color: mouseArea.containsMouse ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                    font.bold: true
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.95
                }

                QQC2.Label {
                    text: (root.sortColumn === col) ? (root.sortAscending ? "▲" : "▼") : ""
                    color: (root.sortColumn === col) ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.8
                    visible: root.sortColumn === col
                }

            }

            Item {
                Layout.fillWidth: true
                visible: alignment === Qt.AlignLeft && extraText !== ""
            }

            QQC2.Label {
                text: extraText
                visible: extraText !== ""
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85
                font.italic: true
                color: Kirigami.Theme.textColor
                opacity: 0.8
            }

        }

        MouseArea {
            id: mouseArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sortClicked()
        }

    }

}
