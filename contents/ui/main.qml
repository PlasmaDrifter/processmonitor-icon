import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property color iconColor:
        Plasmoid.configuration.baseIconColor.length > 0
        ? Plasmoid.configuration.baseIconColor
        : "#c73aa8"

    readonly property bool colorizeIcon: Plasmoid.configuration.colorizeIcon

    Plasmoid.title: i18n("Processor Utility")

    compactRepresentation: MouseArea {
        Layout.minimumWidth:    Kirigami.Units.iconSizes.small
        Layout.minimumHeight:   Kirigami.Units.iconSizes.small
        Layout.preferredWidth:  Kirigami.Units.iconSizes.medium
        Layout.preferredHeight: Kirigami.Units.iconSizes.medium
        onClicked: root.expanded = !root.expanded

        Kirigami.Icon {
            anchors.fill: parent
            source: Plasmoid.configuration.iconName || "ksysguard"
            color:  root.colorizeIcon ? root.iconColor : "transparent"
            isMask: root.colorizeIcon
        }
    }

    fullRepresentation: FullRepresentation {}
}
