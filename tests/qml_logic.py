#!/usr/bin/env python3
"""Check the bar widget's logic offscreen: status parsing, visibility, and when it asks for setup.

Needs quickshell and Omarchy's shell modules (qs.Commons, qs.Ui), which the
harness links in from OMARCHY_SHELL (default /usr/share/omarchy/shell).
"""
import os, re, shutil, subprocess, tempfile, threading
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHELL = Path(os.environ.get("OMARCHY_SHELL", "/usr/share/omarchy/shell"))

if shutil.which("quickshell") is None:
    raise SystemExit("quickshell is not installed; the widget cannot be checked")
if not SHELL.is_dir():
    raise SystemExit(f"Omarchy's shell modules are not at {SHELL}; set OMARCHY_SHELL")

env = dict(os.environ, QT_QPA_PLATFORM="offscreen")
for name in ("WAYLAND_DISPLAY", "DISPLAY", "QT_QPA_PLATFORMTHEME"):
    env.pop(name, None)

with tempfile.TemporaryDirectory(prefix="pop-icon-keys-qml-") as directory:
    harness = Path(directory)
    shutil.copy(ROOT / "tests/qml/shell.qml", harness / "shell.qml")
    # Renamed: Panel.qml extends qs.Ui's Panel and would otherwise resolve to itself.
    # bin/ is not copied, so the widget's own status read finds no helper and
    # never touches a real keyboard.
    shutil.copy(ROOT / "Panel.qml", harness / "BarPanel.qml")
    (harness / "Commons").symlink_to(SHELL / "Commons")
    shutil.copytree(SHELL / "Ui", harness / "Ui", symlinks=True)
    shutil.copy(ROOT / "tests/qml/KeyboardPanel.qml", harness / "Ui/KeyboardPanel.qml")
    runtime = harness / "runtime"
    runtime.mkdir(mode=0o700)
    env["XDG_RUNTIME_DIR"] = str(runtime)

    shell = subprocess.Popen(["quickshell", "-p", str(harness)], stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT, text=True, env=env)
    timer = threading.Timer(30, shell.kill)
    timer.start()
    lines = []
    for line in shell.stdout:
        lines.append(line)
        if re.search(r"qml:\s+(ALL OK|\d+ FAILED)", re.sub(r"\x1b\[[0-9;]*m", "", line)):
            break
    timer.cancel()
    shell.kill()
    shell.wait()
    if os.environ.get("POP_QML_LOG"): open(os.environ["POP_QML_LOG"], "w").write("".join(lines))

plain = re.sub(r"\x1b\[[0-9;]*m", "", "".join(lines))
checks = re.findall(r"qml:\s+(ok|FAIL)\s+(.*?)\s*$", plain, re.MULTILINE)
failed = [name for state, name in checks if state == "FAIL"]
assert checks, "the harness produced no checks:\n" + plain[-3000:]
assert not failed, "failed: " + "; ".join(failed) + "\n" + plain[-3000:]
assert "ALL OK" in plain, "harness did not finish:\n" + plain[-3000:]
print(f'{{"qml_logic_checks": {len(checks)}, "failed": 0}}')
