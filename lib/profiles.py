#!/usr/bin/env python3
"""Keyboard profiles: one JSON file per keyboard model in profiles/.

The only place that knows which keyboards the plugin supports. setup,
uninstall, lib/edit.py, the status and restore helpers (and through them the
bar widget) get keyboard names, key names, control ids and commands from here.
Run with `python3 -I`; stdlib only.

A profile (see CONTRIBUTING.md for the full guide):

  slug          lowercase-with-dashes, same as the file name
  displayName   shown in the bar widget and in setup's plan
  solaarNames   device names as Solaar shows them (`solaar show`, config.yaml _NAME)
  modelId       Solaar's model id (config.yaml _modelId), or null
  tested        true only when someone ran it on the real keyboard
  verified      {"solaar": version, "date": YYYY-MM-DD, "osMode": keyboard OS mode} when tested, else null
  keys          [{name, cid, cap, label, command}] the keys Solaar diverts:
                  name     Solaar's key name (its CONTROL table), used in rules
                  cid      Solaar's control id, used in config.yaml divert-keys
                  cap      what is printed on the key ("F4", "Lock")
                  label    what pressing it does, for people
                  command  argv list run by the Solaar rule; "@show-desktop"
                           stands for the plugin's Show Desktop helper
  hyprBindings  [{cap, bind, label, command, note}] shortcuts the keyboard sends
                that Solaar cannot divert, bound in Hyprland instead (optional)

Command line (for the shell scripts):
  profiles.py validate               check every profile; exit 1 with reasons
  profiles.py list                   "<slug>\t<displayName>\t<tested 0|1>" per profile
  profiles.py known <config.yaml>    the same, for profiles Solaar has a saved entry for
  profiles.py cids <slug>...         "<cid>\t<name>" for each mapped key
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.realpath(__file__))
PROFILE_DIR = os.environ.get("LK_PROFILE_DIR") or os.path.join(os.path.dirname(HERE), "profiles")

SLUG_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
BIND_RE = re.compile(r"^[A-Z0-9_]+( \+ [A-Z0-9_]+)*$")
SHOW_DESKTOP = "@show-desktop"
# Characters a value may not contain: it ends up in YAML, Lua strings and shell output.
BAD_CHARS = re.compile(r'[\n\r\t"\\]')


class ProfileError(Exception):
    pass


def _text(where, value, field, *, allow_empty=False):
    if not isinstance(value, str) or (not value and not allow_empty):
        raise ProfileError(f"{where}: '{field}' must be a non-empty string")
    if BAD_CHARS.search(value):
        raise ProfileError(f"{where}: '{field}' may not contain quotes, backslashes, tabs or newlines")
    return value


def check(profile, filename):
    """Raise ProfileError if PROFILE (parsed JSON from FILENAME) is not a valid profile."""
    where = os.path.basename(filename)
    if not isinstance(profile, dict):
        raise ProfileError(f"{where}: must be a JSON object")
    known = {"slug", "displayName", "solaarNames", "modelId", "tested", "verified", "keys", "hyprBindings"}
    extra = set(profile) - known
    if extra:
        raise ProfileError(f"{where}: unknown field(s) {', '.join(sorted(extra))}")
    slug = _text(where, profile.get("slug"), "slug")
    if not SLUG_RE.match(slug) or where != f"{slug}.json":
        raise ProfileError(f"{where}: slug must be lowercase-with-dashes and match the file name")
    _text(where, profile.get("displayName"), "displayName")
    names = profile.get("solaarNames")
    if not isinstance(names, list) or not names:
        raise ProfileError(f"{where}: 'solaarNames' must be a non-empty list")
    for n in names:
        _text(where, n, "solaarNames")
    model = profile.get("modelId")
    if model is not None and not (isinstance(model, str) and re.match(r"^[0-9A-F]{4,16}$", model)):
        raise ProfileError(f"{where}: 'modelId' must be Solaar's hex model id or null")
    tested = profile.get("tested")
    if not isinstance(tested, bool):
        raise ProfileError(f"{where}: 'tested' must be true or false")
    verified = profile.get("verified")
    if tested:
        if not isinstance(verified, dict) or set(verified) != {"solaar", "date", "osMode"}:
            raise ProfileError(f"{where}: a tested profile needs 'verified' with solaar, date and osMode")
        for k in ("solaar", "date", "osMode"):
            _text(where, verified[k], f"verified.{k}")
        if not re.match(r"^\d{4}-\d{2}-\d{2}$", verified["date"]):
            raise ProfileError(f"{where}: 'verified.date' must be YYYY-MM-DD")
    elif verified is not None:
        raise ProfileError(f"{where}: an untested profile must have 'verified': null")
    keys = profile.get("keys")
    if not isinstance(keys, list) or not keys:
        raise ProfileError(f"{where}: 'keys' must be a non-empty list")
    seen_names, seen_cids = set(), set()
    for i, key in enumerate(keys):
        kw = f"{where}: keys[{i}]"
        if not isinstance(key, dict) or set(key) != {"name", "cid", "cap", "label", "command"}:
            raise ProfileError(f"{kw} must have exactly name, cid, cap, label and command")
        _text(kw, key["name"], "name")
        if ":" in key["name"] or "," in key["name"]:
            raise ProfileError(f"{kw}: 'name' may not contain ':' or ','")
        if not isinstance(key["cid"], int) or isinstance(key["cid"], bool) or not 0 < key["cid"] < 0x10000:
            raise ProfileError(f"{kw}: 'cid' must be Solaar's control id (a whole number)")
        _text(kw, key["cap"], "cap")
        _text(kw, key["label"], "label")
        command = key["command"]
        if not isinstance(command, list) or not command:
            raise ProfileError(f"{kw}: 'command' must be a non-empty list of arguments")
        for part in command:
            _text(kw, part, "command")
        if command[0].startswith("@") and command != [SHOW_DESKTOP]:
            raise ProfileError(f"{kw}: the only '@' command is [\"{SHOW_DESKTOP}\"]")
        if key["name"] in seen_names or key["cid"] in seen_cids:
            raise ProfileError(f"{kw}: key name or cid listed twice")
        seen_names.add(key["name"])
        seen_cids.add(key["cid"])
    binds = profile.get("hyprBindings", [])
    if not isinstance(binds, list):
        raise ProfileError(f"{where}: 'hyprBindings' must be a list")
    for i, b in enumerate(binds):
        bw = f"{where}: hyprBindings[{i}]"
        if not isinstance(b, dict) or set(b) != {"cap", "bind", "label", "command", "note"}:
            raise ProfileError(f"{bw} must have exactly cap, bind, label, command and note")
        for k in ("cap", "label", "command", "note"):
            _text(bw, b[k], k)
        if not BIND_RE.match(_text(bw, b["bind"], "bind")):
            raise ProfileError(f"{bw}: 'bind' must look like \"SUPER + CTRL + Q\"")


def load_all(directory=None):
    """All profiles, sorted by slug. Raises ProfileError on the first problem."""
    directory = directory or PROFILE_DIR
    try:
        files = sorted(f for f in os.listdir(directory) if f.endswith(".json"))
    except OSError as e:
        raise ProfileError(f"cannot read the profiles folder {directory}: {e.strerror}")
    if not files:
        raise ProfileError(f"no profiles in {directory}")
    profiles = []
    for name in files:
        path = os.path.join(directory, name)
        try:
            with open(path, encoding="utf-8") as f:
                data = json.load(f)
        except (OSError, UnicodeDecodeError, json.JSONDecodeError) as e:
            raise ProfileError(f"{name}: not readable JSON ({e})")
        check(data, path)
        data.setdefault("hyprBindings", [])
        profiles.append(data)
    # Across profiles: one Solaar key name must mean one command, since a Solaar
    # rule matches the key name on any keyboard.
    commands = {}
    for p in profiles:
        for key in p["keys"]:
            other = commands.setdefault(key["name"], (p["slug"], key["command"]))
            if other[1] != key["command"]:
                raise ProfileError(f"{p['slug']}.json: key '{key['name']}' runs a different command than in "
                                   f"{other[0]}.json; Solaar rules match key names on every keyboard")
    binds = {}
    for p in profiles:
        for b in p["hyprBindings"]:
            other = binds.setdefault(b["bind"], (p["slug"], b["command"]))
            if other[1] != b["command"]:
                raise ProfileError(f"{p['slug']}.json: {b['bind']} is bound to a different command in {other[0]}.json")
    return profiles


def config_entries(config_path):
    """(name, model_id) for each device entry in Solaar's config.yaml."""
    try:
        with open(config_path, encoding="utf-8") as f:
            lines = f.read().replace("\r\n", "\n").split("\n")
    except FileNotFoundError:
        return []
    entries = []
    name_re = re.compile(r"^- _NAME:\s*(.*?)\s*$")
    model_re = re.compile(r"^\s+_modelId:\s*(\S+)\s*$")
    for line in lines:
        m = name_re.match(line)
        if m:
            entries.append([m.group(1), None])
            continue
        if line[:1] not in ("", " ", "\t"):
            entries.append([None, None])  # a top-level item that is not a device
            continue
        m = model_re.match(line)
        if m and entries and entries[-1][0] is not None:
            entries[-1][1] = m.group(1)
    return [tuple(e) for e in entries if e[0] is not None]


def matches(profile, name, model):
    return name in profile["solaarNames"] or (model is not None and model == profile.get("modelId"))


def known(profiles, config_path):
    """[(profile, [saved device names])] for profiles with a saved Solaar entry."""
    entries = config_entries(config_path)
    out = []
    for p in profiles:
        names = [n for n, m in entries if matches(p, n, m)]
        if names:
            out.append((p, list(dict.fromkeys(names))))
    return out


def by_slug(profiles, slugs):
    table = {p["slug"]: p for p in profiles}
    missing = [s for s in slugs if s not in table]
    if missing:
        raise ProfileError(f"no profile named {', '.join(missing)}")
    return [table[s] for s in slugs]


def main(argv):
    if not argv:
        raise SystemExit(__doc__.split("Command line")[1])
    command, args = argv[0], argv[1:]
    try:
        profiles = load_all()
        if command == "validate":
            print(f"{len(profiles)} profile(s) valid: {', '.join(p['slug'] for p in profiles)}")
        elif command == "list":
            for p in profiles:
                print(f"{p['slug']}\t{p['displayName']}\t{int(p['tested'])}")
        elif command == "known":
            for p, _ in known(profiles, args[0]):
                print(f"{p['slug']}\t{p['displayName']}\t{int(p['tested'])}")
        elif command == "cids":
            for p in by_slug(profiles, args):
                for key in p["keys"]:
                    print(f"{key['cid']}\t{key['name']}")
        else:
            raise SystemExit(f"profiles.py: unknown command {command}")
    except ProfileError as e:
        print(f"error: profile: {e}", file=sys.stderr)
        sys.exit(4)


if __name__ == "__main__":
    main(sys.argv[1:])
