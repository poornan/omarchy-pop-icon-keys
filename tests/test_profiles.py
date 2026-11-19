#!/usr/bin/env python3
"""Check every keyboard profile, its fixtures, and that the profile reader refuses bad ones.

  python3 tests/test_profiles.py

A contributor adding profiles/<slug>.json runs this first: it fails with the
profile's file name and the field at fault.
"""
import copy
import json
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "lib"))
import profiles as P  # noqa: E402

checks = failures = 0


def check(name, ok):
    global checks, failures
    checks += 1
    if ok:
        print(f"  ok   {name}")
    else:
        failures += 1
        print(f"  FAIL {name}")


def refused(name, mutate, base, want=None):
    """A copy of BASE changed by MUTATE must be refused (WANT: text in the reason)."""
    data = copy.deepcopy(base)
    mutate(data)
    with tempfile.TemporaryDirectory() as d:
        with open(os.path.join(d, f"{data.get('slug', base['slug'])}.json"), "w") as f:
            json.dump(data, f)
        try:
            P.load_all(d)
        except P.ProfileError as e:
            check(name, want is None or want in str(e))
            return
    check(name + " (was accepted)", False)


print("shipped profiles")
profiles = P.load_all()
check("all profiles load and validate", len(profiles) >= 2)
slugs = [p["slug"] for p in profiles]
for p in profiles:
    folder = os.path.join(ROOT, "tests", "fixtures", p["slug"])
    for case in ("routed", "dropped", "not-setup"):
        path = os.path.join(folder, f"{case}.txt")
        ok = os.path.isfile(path)
        if ok:
            text = open(path, encoding="utf-8").read()
            ok = any(n in text for n in p["solaarNames"]) and "Key/Button Diversion" in text
        check(f"{p['slug']}: fixture {case}.txt present and names the keyboard", ok)
    listed = open(os.path.join(ROOT, "README.md"), encoding="utf-8").read()
    check(f"{p['slug']}: listed in the README's supported keyboards", p["displayName"] in listed)
    check(f"{p['slug']}: untested profiles have no 'verified'", p["tested"] or p["verified"] is None)

print("Solaar's own names and ids")
pop = P.by_slug(profiles, ["pop-icon-keys"])[0]
ids = {k["name"]: k["cid"] for k in pop["keys"]}
check("POP: MultiPlatform Search is 212", ids.get("MultiPlatform Search") == 212)
check("POP: Screen Capture is 266", ids.get("Screen Capture") == 266)
check("POP: Show Desktop 110, Dictation 259, Emoji 264",
      (ids.get("Show Desktop"), ids.get("Dictation"), ids.get("Emoji")) == (110, 259, 264))
mx = P.by_slug(profiles, ["mx-keys-mac"])[0]
check("MX Keys for Mac is marked untested", mx["tested"] is False)
check("MX: Launchpad 225, Print Screen 191, Screen Lock 111, Calculator 10",
      {k["cid"]: k["name"] for k in mx["keys"]} == {225: "Dashboard Launchpad/Action Center",
                                                   191: "Screen Capture/Print Screen",
                                                   111: "Screen Lock", 10: "Calculator"})
# Against Solaar's key table, when Solaar is installed here.
try:
    from logitech_receiver import special_keys  # type: ignore
    wrong = [f"{p['slug']}:{k['cid']}" for p in profiles for k in p["keys"]
             if str(special_keys.CONTROL[k["cid"]]) != k["name"]]
    check("every key name matches Solaar's CONTROL table for its id", not wrong)
except ImportError:
    print("  skip Solaar's key table (Solaar not installed)")

print("bad profiles are refused")
base = copy.deepcopy(pop)
refused("cid not a number", lambda d: d["keys"][0].update(cid="110"), base, "cid")
refused("missing command", lambda d: d["keys"][0].pop("command"), base, "keys[0]")
refused("unknown field", lambda d: d.update(colour="red"), base, "unknown field")
refused("slug not matching the file name", lambda d: d.update(slug="Pop Keys"), base)
refused("quote in a command", lambda d: d["keys"][1].update(command=['echo "hi"']), base, "quotes")
refused("tested without 'verified'", lambda d: d.update(verified=None), base, "verified")
refused("untested with 'verified'", lambda d: d.update(tested=False), base, "untested")
refused("an unknown @ command", lambda d: d["keys"][0].update(command=["@other"]), base, "@")
refused("a bind that is not a Hyprland chord", lambda d: d["hyprBindings"][0].update(bind="super+q"), base, "bind")
refused("same key listed twice", lambda d: d["keys"].append(copy.deepcopy(d["keys"][0])), base, "twice")

with tempfile.TemporaryDirectory() as d:
    for p in profiles:
        with open(os.path.join(d, f"{p['slug']}.json"), "w") as f:
            json.dump(p, f)
    clash = copy.deepcopy(mx)
    clash["keys"][0]["name"] = "Emoji"
    clash["keys"][0]["cid"] = 264
    with open(os.path.join(d, "mx-keys-mac.json"), "w") as f:
        json.dump(clash, f)
    try:
        P.load_all(d)
        check("two profiles, one key name, two commands: refused", False)
    except P.ProfileError as e:
        check("two profiles, one key name, two commands: refused", "different command" in str(e))

print("the reader's command line")
out = subprocess.run([sys.executable, "-I", os.path.join(ROOT, "lib", "profiles.py"), "validate"],
                     capture_output=True, text=True)
check("validate exits 0", out.returncode == 0)
with tempfile.TemporaryDirectory() as d:
    cfg = os.path.join(d, "config.yaml")
    with open(cfg, "w") as f:
        f.write("- 1.1.20\n- _NAME: Some Other Name\n  _modelId: B36140920000\n  divert-keys: {10: 0}\n"
                "- _NAME: MX Master 4\n  _modelId: B04200000000\n")
    out = subprocess.run([sys.executable, "-I", os.path.join(ROOT, "lib", "profiles.py"), "known", cfg],
                         capture_output=True, text=True)
    check("known: matched by model id when the name differs", out.stdout.split("\t")[0] == "mx-keys-mac")
    check("known: a mouse is not a profiled keyboard", "pop-icon-keys" not in out.stdout and out.stdout.count("\n") == 1)
    bad = os.path.join(d, "profiles")
    shutil.copytree(os.path.join(ROOT, "profiles"), bad)
    with open(os.path.join(bad, "pop-icon-keys.json"), "w") as f:
        f.write("{not json")
    out = subprocess.run([sys.executable, "-I", os.path.join(ROOT, "lib", "profiles.py"), "validate"],
                         capture_output=True, text=True, env=dict(os.environ, LK_PROFILE_DIR=bad))
    check("a broken profile file: exit 4 naming the file", out.returncode == 4 and "pop-icon-keys.json" in out.stderr)

print()
if failures:
    print(f"{failures} of {checks} checks FAILED")
    sys.exit(1)
print(f"ALL OK ({checks} checks)")
