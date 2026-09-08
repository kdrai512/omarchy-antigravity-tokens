import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "mrworld.antigravity-tokens"

  readonly property var tokenData: parseTokenData(tokenDataFile.text())
  readonly property int remainingPercent: tokenData && tokenData.remainingPercent !== undefined ? tokenData.remainingPercent : 100
  readonly property string formattedRemaining: tokenData && tokenData.formattedRemaining ? tokenData.formattedRemaining : "—"
  readonly property string formattedMax: tokenData && tokenData.formattedMax ? tokenData.formattedMax : "1M"
  readonly property string accountEmail: tokenData && tokenData.account ? tokenData.account : ""
  readonly property string resetIn: tokenData && tokenData.resetIn ? tokenData.resetIn : ""
  readonly property bool ready: tokenData && tokenData.ready === true

  function parseTokenData(str) {
    if (!str || str.trim() === "") return null
    try {
      return JSON.parse(str)
    } catch (e) {
      return null
    }
  }

  function refresh() {
    if (!fetchProcess.running) {
      fetchProcess.running = true
    }
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("tokenData" in target) target.tokenData = root.tokenData
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    injectPanel()
    if (panelLoader.item && panelLoader.item.open) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  function togglePanel() {
    injectPanel()
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  function closeForPopoutSwitch() {
    if (panelLoader.item && panelLoader.item.closeForPopoutSwitch) panelLoader.item.closeForPopoutSwitch()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()
  onTokenDataChanged: injectPanel()

  FileView {
    id: tokenDataFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/antigravity/tokens.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
  }

  readonly property string scriptPath: Qt.resolvedUrl("fetch-tokens.py").toString().replace(/^file:\/\//, "")

  Process {
    id: fetchProcess
    command: ["python3", root.scriptPath]
    running: false
    onExited: {
      tokenDataFile.reload()
    }
  }

  // Refresh every 5 minutes (300 seconds)
  Timer {
    interval: 300000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: {
    tokenDataFile.reload()
    root.refresh()
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    active: root.opened
    horizontalMargin: 8.5
    verticalPadding: 6

    text: root.ready ? ("✦ " + root.remainingPercent + "%") : "✦ …"
    tooltipText: root.ready
      ? ("Antigravity Quota: " + root.formattedRemaining + " / " + root.formattedMax + " tokens (" + root.remainingPercent + "%)\nAccount: " + root.accountEmail + (root.resetIn ? "\nResets in " + root.resetIn : ""))
      : "Antigravity Quota: Loading token metrics…"

    foreground: root.remainingPercent <= 15
      ? (root.bar ? root.bar.urgent : Color.urgent)
      : (root.bar ? root.bar.barForeground : Color.foreground)

    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.RightButton || b === Qt.MiddleButton) {
        root.refresh()
      } else {
        root.togglePanel()
      }
    }
  }
}
