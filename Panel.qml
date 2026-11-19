import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Logitech POP Icon Keys in the bar: keyboard battery, the top-row key map,
// and whether Solaar is running and routing each mapped key.
Panel {
  id: root
  moduleName: "io.github.poornan.pop-icon-keys"
  ipcTarget: "pop-icon-keys"
  manageIpc: false

  readonly property string pluginDir: decodeURIComponent(String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "")).replace(/\/$/, "")
  readonly property bool hideWhenDisconnected: setting("hideWhenDisconnected", true) === true
  readonly property bool showPercentage: setting("showPercentage", false) === true

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // Filled from bin/pop-icon-keys-status (key=value lines).
  property bool loaded: false
  property bool solaarInstalled: true
  property bool solaarRunning: false
  property bool connected: false
  property int battery: -1
  property var divertedKeys: []
  property var missingKeys: []

  readonly property int lowBatteryPercent: 15
  readonly property bool lowBattery: connected && battery >= 0 && battery <= lowBatteryPercent
  readonly property bool needsSetup: loaded && (!solaarInstalled || (connected && (!solaarRunning || missingKeys.length > 0)))

  readonly property color barIconColor: !connected ? Qt.darker(barForeground, 1.55)
    : (lowBattery || needsSetup) ? urgent
    : barForeground

  // Each row: the key, its Solaar name (empty for keys Hyprland handles), and the Omarchy action.
  readonly property var keyMap: [
    { key: "F4", solaar: "Show Desktop", action: "Empty workspace, again to return" },
    { key: "F5", solaar: "MultiPlatform Search", action: "App launcher" },
    { key: "F6", solaar: "Dictation", action: "Dictation (omarchy-dictation)" },
    { key: "F7", solaar: "Emoji", action: "Emoji picker" },
    { key: "F8", solaar: "Screen Capture", action: "Region screenshot" },
    { key: "Lock", solaar: "", action: "Lock screen (Super+Ctrl+Q)" }
  ]

  function keyRouted(name) {
    if (name === "") return true
    return divertedKeys.indexOf(name) !== -1
  }

  function statusLine() {
    if (!loaded) return "Checking…"
    if (!solaarInstalled) return "Solaar is not installed"
    if (!connected) return "Keyboard not connected"
    if (!solaarRunning) return "Solaar is not running"
    if (missingKeys.length > 0) return missingKeys.length + " key(s) not routed. Run setup"
    return "All keys routed"
  }

  function parseStatus(text) {
    var values = {}
    String(text || "").split("\n").forEach(function (line) {
      var at = line.indexOf("=")
      if (at > 0) values[line.slice(0, at)] = line.slice(at + 1)
    })
    function list(raw) { return raw ? raw.split(",").filter(function (s) { return s !== "" }) : [] }
    solaarInstalled = values.installed !== "0"
    solaarRunning = values.running === "1"
    connected = values.connected === "1"
    var level = parseInt(values.battery, 10)
    battery = isFinite(level) ? level : -1
    divertedKeys = list(values.diverted)
    missingKeys = list(values.missing)
    loaded = true
  }

  function refresh() {
    if (pluginDir === "" || statusProc.running) return
    statusProc.running = true
  }

  // Setup asks before changing any file, so it runs in a terminal the user can answer.
  function runSetup() {
    if (pluginDir === "") return
    Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", pluginDir + "/setup"])
    close()
  }

  // Shown while there is something to see or fix; hidden setting applies only to a quiet, absent keyboard.
  readonly property bool shown: !hideWhenDisconnected || connected || needsSetup
  visible: shown
  implicitWidth: visible ? button.implicitWidth : 0
  implicitHeight: visible ? button.implicitHeight : 0

  onOpenedChanged: if (opened) {
    refresh()
    Qt.callLater(function () { keyCatcher.forceActiveFocus() })
  }

  Component.onCompleted: refresh()

  Process {
    id: statusProc
    command: [root.pluginDir + "/bin/pop-icon-keys-status"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parseStatus(text) }
  }

  // `solaar show` talks to the keyboard and takes a few seconds, so poll gently.
  Timer { interval: 120000; running: true; repeat: true; onTriggered: root.refresh() }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refresh(); return "ok" }
    function status(): string { return root.statusLine() }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰌌"
    foreground: root.barIconColor
    labelText: root.showPercentage && root.battery >= 0 && !vertical ? root.battery + "%" : ""
    slotSize: Style.bar.iconSlot * (labelText !== "" ? 2 : 1)
    tooltipText: root.connected && root.battery >= 0 ? "POP Icon Keys " + root.battery + "%" : "POP Icon Keys"
    onPressed: function (buttonCode) {
      if (buttonCode === Qt.RightButton) root.refresh()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function (direction) { root.switchPanel(direction) }
      onTextKey: function (t) {
        var key = String(t).toLowerCase()
        if (key === "r") root.refresh()
        else if (key === "s") root.runSetup()
      }

      Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: flick.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            title: "POP Icon Keys"
            meta: root.connected && root.battery >= 0 ? "Battery " + root.battery + "%" : root.statusLine()
            detail: root.connected ? root.statusLine() : ""
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconOpacity: root.connected ? 1.0 : 0.5
            iconComponent: Component {
              Text {
                textFormat: Text.PlainText
                text: "󰌌"
                color: root.needsSetup ? root.urgent : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.space(34)
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "KEY MAP"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Repeater {
              model: root.keyMap

              Item {
                required property var modelData
                readonly property bool routed: root.keyRouted(modelData.solaar)
                width: column.width
                implicitHeight: actionText.implicitHeight

                Text {
                  id: keyText
                  textFormat: Text.PlainText
                  width: Style.space(48)
                  text: modelData.key
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                }

                Text {
                  id: actionText
                  textFormat: Text.PlainText
                  anchors.left: keyText.right
                  anchors.right: stateText.left
                  anchors.rightMargin: Style.space(8)
                  text: modelData.action
                  color: root.foreground
                  elide: Text.ElideRight
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                }

                Text {
                  id: stateText
                  textFormat: Text.PlainText
                  anchors.right: parent.right
                  // Unknown until the first status read; keys Hyprland handles are always shown as ready.
                  text: !root.loaded || !root.connected ? "" : (routed ? "✓" : "not routed")
                  color: routed ? root.dim : root.urgent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "SOLAAR"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              textFormat: Text.PlainText
              width: parent.width
              wrapMode: Text.WordWrap
              text: !root.loaded ? "Checking…"
                : !root.solaarInstalled ? "Not installed. Setup can install it."
                : root.solaarRunning ? "Running in the background"
                : "Not running. Setup starts it and adds it to autostart."
              color: root.solaarInstalled && root.solaarRunning ? root.dim : root.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }

            Row {
              spacing: Style.space(8)

              Button {
                text: "Re-apply setup"
                tooltipText: "Opens a terminal; setup lists its changes and asks first (s)"
                foreground: root.foreground
                bordered: true
                onClicked: root.runSetup()
              }

              Button {
                text: "Refresh"
                tooltipText: "Read the keyboard again (r)"
                foreground: root.foreground
                bordered: true
                onClicked: root.refresh()
              }
            }
          }
        }
      }
    }
  }
}
