import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.iconthemes as KIconThemes
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: page

    property alias cfg_refreshInterval: refreshSpin.value
    property alias cfg_colorizeIcon: colorizeCheck.checked
    property alias cfg_systemUptimeDisplay: uptimeDisplayCombo.currentIndex
    // cfg_baseIconColor and cfg_iconName are handled manually below since
    // they need custom widgets (icon picker button, color swatch/dialog)
    // that plain aliases can't express.
    property string cfg_baseIconColor: "#c73aa8"
    property string cfg_iconName: "ksysguard"

    RowLayout {
        Kirigami.FormData.label: i18n("Panel icon:")
        spacing: Kirigami.Units.smallSpacing

        QQC2.Button {
            icon.name: page.cfg_iconName.length > 0 ? page.cfg_iconName : "ksysguard"
            text: i18n("Choose Icon…")
            onClicked: iconDialog.open()
        }

        QQC2.ToolButton {
            icon.name: "edit-clear"
            text: i18n("Reset to default")
            display: QQC2.AbstractButton.IconOnly
            onClicked: page.cfg_iconName = "ksysguard"
            QQC2.ToolTip.text: text
            QQC2.ToolTip.visible: hovered
        }

    }

    KIconThemes.IconDialog {
        id: iconDialog

        onIconNameChanged: (iconName) => {
            if (iconName.length > 0)
                page.cfg_iconName = iconName;

        }
    }

    QQC2.CheckBox {
        id: colorizeCheck

        Kirigami.FormData.label: i18n("Colourize icon:")
        text: i18n("Tint icon with a custom colour")
    }

    RowLayout {
        Kirigami.FormData.label: i18n("Icon colour:")
        spacing: Kirigami.Units.smallSpacing
        enabled: colorizeCheck.checked
        opacity: colorizeCheck.checked ? 1 : 0.4

        Rectangle {
            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
            radius: 4
            color: page.cfg_baseIconColor
            border.color: Kirigami.Theme.disabledTextColor
            border.width: 1

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: colorDialog.open()
            }

        }

        QQC2.Button {
            text: i18n("Choose Color…")
            onClicked: colorDialog.open()
        }

        QQC2.ToolButton {
            icon.name: "edit-clear"
            text: i18n("Reset to default")
            display: QQC2.AbstractButton.IconOnly
            onClicked: page.cfg_baseIconColor = "#c73aa8"
            QQC2.ToolTip.text: text
            QQC2.ToolTip.visible: hovered
        }

    }

    ColorDialog {
        id: colorDialog

        title: i18n("Choose Panel Icon Color")
        selectedColor: page.cfg_baseIconColor
        onAccepted: page.cfg_baseIconColor = selectedColor.toString()
    }

    QQC2.SpinBox {
        id: refreshSpin

        Kirigami.FormData.label: i18n("Refresh interval (seconds):")
        from: 1
        to: 60
    }

    QQC2.ComboBox {
        id: uptimeDisplayCombo
        Kirigami.FormData.label: i18n("System uptime display:")
        model: [
            i18n("Disabled"),
            i18n("Name Column Header"),
            i18n("Bottom Status Bar")
        ]
    }
}
