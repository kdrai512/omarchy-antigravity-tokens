import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "mrworld.antigravity-tokens"
  ipcTarget: "mrworld.antigravity-tokens"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  property var tokenData: null

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function refresh() {
    if (hostWidget && hostWidget.refresh) hostWidget.refresh()
  }

  function open() {
    root.controller.show()
    refresh()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) close()
    else open()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight + Style.space(28))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        id: scroller
        anchors.fill: parent
        anchors.margins: Style.space(14)
        contentWidth: width
        contentHeight: mainColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: mainColumn
          width: scroller.width
          spacing: Style.space(14)

          // Header
          Item {
            width: parent.width
            implicitHeight: Math.max(headerLeft.implicitHeight, refreshBtn.implicitHeight)

            Row {
              id: headerLeft
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(10)

              Text {
                text: "✦"
                font.pixelSize: Style.font.heading
                color: Color.accent
                anchors.verticalCenter: parent.verticalCenter
              }

              Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(2)

                Text {
                  text: "Google Antigravity"
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                  color: root.foreground
                }

                Text {
                  text: root.tokenData && root.tokenData.account ? root.tokenData.account : "Google Account"
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  color: root.dim
                }
              }
            }

            PanelActionButton {
              id: refreshBtn
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              iconText: "↻"
              tooltipText: "Refresh quota"
              onClicked: root.refresh()
            }
          }

          PanelSeparator {
            width: parent.width
          }

          // Main Quota Card
          Rectangle {
            width: parent.width
            implicitHeight: quotaCol.implicitHeight + Style.space(24)
            radius: Style.cornerRadius
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
            border.width: 1
            border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)

            Column {
              id: quotaCol
              anchors.fill: parent
              anchors.margins: Style.space(14)
              spacing: Style.space(10)

              Item {
                width: parent.width
                implicitHeight: Math.max(labelsCol.implicitHeight, pctText.implicitHeight)

                Column {
                  id: labelsCol
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(2)

                  Text {
                    text: "AVAILABLE TOKENS"
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    font.letterSpacing: 1.1
                    color: root.dim
                  }

                  Text {
                    text: root.tokenData ? (root.tokenData.formattedRemaining + " / " + root.tokenData.formattedMax) : "—"
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.display
                    font.bold: true
                    color: root.foreground
                  }
                }

                Text {
                  id: pctText
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.tokenData && root.tokenData.remainingPercent !== undefined
                    ? (root.tokenData.remainingPercent + "%")
                    : "—"
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.display
                  font.bold: true
                  color: (root.tokenData && root.tokenData.remainingPercent <= 15) ? root.urgent : Color.accent
                }
              }

              // Gauge meter bar
              Rectangle {
                width: parent.width
                height: Style.space(8)
                radius: Style.cornerRadius
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)

                Rectangle {
                  anchors.left: parent.left
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  width: parent.width * Math.max(0, Math.min(1, root.tokenData && root.tokenData.remainingFraction !== undefined ? root.tokenData.remainingFraction : 0))
                  radius: Style.cornerRadius
                  color: (root.tokenData && root.tokenData.remainingPercent <= 15) ? root.urgent : Color.accent

                  Behavior on width {
                    NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                  }
                }
              }

              Item {
                width: parent.width
                implicitHeight: Math.max(resetLabel.implicitHeight, offlineLabel.implicitHeight)

                Text {
                  id: resetLabel
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  visible: root.tokenData && root.tokenData.resetIn !== ""
                  text: "Quota window resets in " + (root.tokenData ? root.tokenData.resetIn : "")
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  color: root.dim
                }

                Text {
                  id: offlineLabel
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  visible: root.tokenData && root.tokenData.stale === true
                  text: "(offline cache)"
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  color: root.dim
                }
              }
            }
          }

          // Section Header
          PanelSectionHeader {
            text: "MODEL QUOTAS"
          }

          // Models List
          Column {
            width: parent.width
            spacing: Style.space(6)

            Repeater {
              model: root.tokenData && root.tokenData.models ? root.tokenData.models : []

              delegate: Rectangle {
                id: modelDelegate
                required property var modelData
                width: parent.width
                implicitHeight: Style.space(34)
                radius: Style.cornerRadius
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)

                // Fill indicator
                Rectangle {
                  anchors.left: parent.left
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  width: parent.width * Math.max(0, Math.min(1, modelData.remainingFraction || 0))
                  radius: Style.cornerRadius
                  color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
                }

                Text {
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(12)
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.name
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  color: root.foreground
                }

                Text {
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(12)
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.formattedRemaining + " (" + modelData.remainingPercent + "%)"
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                  color: modelData.remainingPercent <= 15 ? root.urgent : root.dim
                }
              }
            }
          }
        }
      }
    }
  }
}
