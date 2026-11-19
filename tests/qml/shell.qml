import Quickshell
import QtQuick

// Drives the real Panel.qml's status parsing and bar decisions offscreen,
// with canned helper output in place of `solaar show`.
ShellRoot {
  Item {
    id: harness
    property int failures: 0

    function check(name, got, want) {
      if (String(got) === String(want)) {
        console.log("  ok   " + name)
      } else {
        failures++
        console.log("  FAIL " + name + ": got " + JSON.stringify(got) + ", wanted " + JSON.stringify(want))
      }
    }

    function status(lines) { barPanel.parseStatus(lines.join("\n") + "\n") }

    Component.onCompleted: {
      var all = "Show Desktop,MultiPlatform Search,Dictation,Emoji,Screen Capture"

      console.log("before the first read")
      check("hidden until connected", barPanel.shown, false)
      check("says it is checking", barPanel.statusLine(), "Checking…")

      console.log("everything routed")
      status(["installed=1", "running=1", "connected=1", "battery=80", "diverted=" + all, "missing="])
      check("battery parsed", barPanel.battery, 80)
      check("visible when connected", barPanel.shown, true)
      check("no setup needed", barPanel.needsSetup, false)
      check("status line", barPanel.statusLine(), "All keys routed")
      check("F6 routed", barPanel.keyRouted("Dictation"), true)
      check("Lock needs no Solaar routing", barPanel.keyRouted(""), true)
      check("icon uses bar colour", String(barPanel.barIconColor), String(barPanel.barForeground))

      console.log("two keys fell back to Regular")
      status(["installed=1", "running=1", "connected=1", "battery=80",
              "diverted=Show Desktop,MultiPlatform Search,Screen Capture", "missing=Dictation,Emoji"])
      check("setup needed", barPanel.needsSetup, true)
      check("F7 not routed", barPanel.keyRouted("Emoji"), false)
      check("status names the count", barPanel.statusLine(), "2 key(s) not routed. Run setup")
      check("icon turns urgent", String(barPanel.barIconColor), String(barPanel.urgent))

      console.log("low battery")
      status(["installed=1", "running=1", "connected=1", "battery=10", "diverted=" + all, "missing="])
      check("low battery flagged", barPanel.lowBattery, true)
      check("icon turns urgent", String(barPanel.barIconColor), String(barPanel.urgent))

      console.log("Solaar stopped")
      status(["installed=1", "running=0", "connected=1", "battery=80", "diverted=" + all, "missing="])
      check("setup needed", barPanel.needsSetup, true)
      check("status line", barPanel.statusLine(), "Solaar is not running")

      console.log("keyboard away")
      status(["installed=1", "running=1", "connected=0", "battery=", "diverted=", "missing="])
      check("battery unknown", barPanel.battery, -1)
      check("hidden while disconnected", barPanel.shown, false)
      check("no setup nag while away", barPanel.needsSetup, false)

      console.log("Solaar missing")
      status(["installed=0", "running=0", "connected=0", "battery=", "diverted=", "missing="])
      check("setup needed", barPanel.needsSetup, true)
      check("shown so setup can be reached", barPanel.shown, true)
      check("status line", barPanel.statusLine(), "Solaar is not installed")

      console.log("keyboard dropped keys after sleep (auto-restore held back)")
      barPanel.lastAutoRestore = Date.now()
      status(["installed=1", "running=1", "connected=1", "battery=80", "diverted=",
              "saved=" + all, "missing=", "inactive=" + all])
      check("restore needed", barPanel.needsRestore, true)
      check("setup not needed", barPanel.needsSetup, false)
      check("status line", barPanel.statusLine(), "Keyboard dropped 5 key(s). Restore")
      check("row says dropped", barPanel.keyState("Dictation"), "dropped")
      check("icon turns urgent", String(barPanel.barIconColor), String(barPanel.urgent))

      console.log("one key missing from the saved settings, one dropped")
      status(["installed=1", "running=1", "connected=1", "battery=80",
              "diverted=Show Desktop,MultiPlatform Search,Screen Capture",
              "saved=Show Desktop,MultiPlatform Search,Screen Capture,Emoji",
              "missing=Dictation", "inactive=Emoji"])
      check("setup wins the status line", barPanel.statusLine(), "1 key(s) not routed. Run setup")
      check("missing row", barPanel.keyState("Dictation"), "not routed")
      check("dropped row", barPanel.keyState("Emoji"), "dropped")
      check("routed row", barPanel.keyState("Show Desktop"), "✓")

      console.log("auto-restore fires once, then waits a minute")
      barPanel.lastAutoRestore = 0
      status(["installed=1", "running=1", "connected=1", "battery=80", "diverted=",
              "saved=" + all, "missing=", "inactive=" + all])
      var first = barPanel.lastAutoRestore
      check("auto-restore started", first > 0, true)
      status(["installed=1", "running=1", "connected=1", "battery=80", "diverted=",
              "saved=" + all, "missing=", "inactive=" + all])
      check("not again within a minute", barPanel.lastAutoRestore, first)

      console.log("no restore while Solaar is stopped")
      status(["installed=1", "running=0", "connected=1", "battery=80", "diverted=",
              "saved=" + all, "missing=", "inactive=" + all])
      check("restore not offered", barPanel.needsRestore, false)
      check("setup offered instead", barPanel.needsSetup, true)

      console.log(failures === 0 ? "ALL OK" : failures + " FAILED")
    }
  }

  BarPanel { id: barPanel }
}
