#!/usr/bin/env python3
"""File edits for setup and uninstall. Run with `python3 -I`; called from lib.sh.

Every edit reads the whole file, computes the new text, and then:
  - leaves the file alone when nothing would change (no backup, no write);
  - under POP_DRY_RUN=1 prints a unified diff instead of writing;
  - otherwise backs the file up (keeping the newest few backups), and replaces
    it atomically through a temporary file in the same folder. A symlinked file
    is written through to its target. CRLF line endings are kept.

Exit codes: 0 done, 3 no saved entry for the device, 4 file unreadable or not
understood, 5 broken marker lines. Messages go to stderr; nothing is changed on
a non-zero exit.
"""
import difflib
import glob
import os
import re
import shutil
import sys
import tempfile
import time

MARK = "pop-icon-keys"
KEEP_BACKUPS = int(os.environ.get("POP_KEEP_BACKUPS", "3"))
DRY_RUN = os.environ.get("POP_DRY_RUN") == "1"

# The rules this plugin writes. Key name -> Execute command (the Show Desktop
# helper path is filled in at run time). Uninstall and setup recognise these
# exact rules even after Solaar's own editor has rewritten rules.yaml and
# dropped the marker comments.
RULES = [
    ("Show Desktop", "F4 Show Desktop -> empty workspace (press again to return)", None),
    ("MultiPlatform Search", "F5 Search -> Omarchy app launcher", ["omarchy-shell", "omarchy.dock", "apps"]),
    ("Dictation", "F6 Dictation -> Omarchy dictation (same as Alt+Space; follows the chosen backend)", ["omarchy-dictation", "toggle"]),
    ("Emoji", "F7 Emoji -> Omarchy emoji picker", ["omarchy-shell", "shell", "toggle", "omarchy.emojis"]),
    ("Screen Capture", "F8 Screen Capture -> region screenshot", ["omarchy-capture-screenshot", "region"]),
]
SHOW_DESKTOP_NAME = "pop-icon-keys-show-desktop"


class Refuse(Exception):
    def __init__(self, code, message):
        super().__init__(message)
        self.code = code


# --- reading and writing ------------------------------------------------------

def read(path):
    """Return (text with LF newlines, uses_crlf). A missing file reads as empty."""
    if not os.path.exists(path):
        return "", False
    try:
        with open(path, "rb") as f:
            raw = f.read()
        text = raw.decode("utf-8")
    except UnicodeDecodeError:
        raise Refuse(4, f"{path} is not UTF-8 text; left unchanged")
    except OSError as e:
        raise Refuse(4, f"cannot read {path}: {e.strerror}")
    crlf = "\r\n" in text
    return (text.replace("\r\n", "\n") if crlf else text), crlf


def backup(path):
    """Copy PATH next to itself as PATH.bak.pop-icon-keys.<time>, keep the newest few."""
    stamp = time.strftime("%Y%m%d-%H%M%S")
    target = f"{path}.bak.{MARK}.{stamp}"
    n = 1
    while os.path.exists(target):
        n += 1
        target = f"{path}.bak.{MARK}.{stamp}-{n}"
    shutil.copy2(path, target)
    olds = sorted(glob.glob(glob.escape(path) + f".bak.{MARK}.*"), key=os.path.getmtime, reverse=True)
    for old in olds[KEEP_BACKUPS:]:
        try:
            os.remove(old)
        except OSError:
            pass
    return target


def commit(path, old, new, crlf):
    """Write NEW over OLD at PATH (see module docstring). Returns True if it changed."""
    if new == old:
        print(f"  unchanged: {path}")
        return False
    if DRY_RUN:
        print(f"  [dry-run] would change {path}:")
        diff = difflib.unified_diff(old.splitlines(), new.splitlines(), "before", "after", lineterm="", n=1)
        for line in list(diff)[2:]:
            print("      " + line)
        return True
    data = (new.replace("\n", "\r\n") if crlf else new).encode("utf-8")
    real = os.path.realpath(path)
    folder = os.path.dirname(real) or "."
    os.makedirs(folder, exist_ok=True)
    mode = None
    if os.path.exists(real):
        mode = os.stat(real).st_mode & 0o7777
        print(f"  backup: {backup(path)}")
    fd, tmp = tempfile.mkstemp(prefix=f".{os.path.basename(real)}.", dir=folder)
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(data)
            f.flush()
            os.fsync(f.fileno())
        if mode is not None:
            os.chmod(tmp, mode)
        else:
            os.chmod(tmp, 0o666 & ~current_umask())
        os.replace(tmp, real)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise
    print(f"  changed: {path}")
    return True


def current_umask():
    mask = os.umask(0)
    os.umask(mask)
    return mask


# --- marked blocks ------------------------------------------------------------

def markers(lines, comment):
    begin, end = f"{comment} BEGIN {MARK}", f"{comment} END {MARK}"
    b = [i for i, line in enumerate(lines) if line.rstrip() == begin]
    e = [i for i, line in enumerate(lines) if line.rstrip() == end]
    return begin, end, b, e


def check_markers(path, lines, comment):
    """Return (begin, end, span) where span is (b, e) or None; refuse on broken markers."""
    begin, end, b, e = markers(lines, comment)
    if not b and not e:
        return begin, end, None
    if len(b) == 1 and len(e) == 1 and b[0] < e[0]:
        return begin, end, (b[0], e[0])
    raise Refuse(5, f"{path} has {len(b)} '{begin}' and {len(e)} '{end}' line(s); expected one of each, "
                    f"BEGIN first. Fix the file by hand (or remove both lines), then run again. Nothing was changed.")


def replace_block(path, text, comment, body):
    lines = text.split("\n")
    begin, end, span = check_markers(path, lines, comment)
    body_lines = body.rstrip("\n").split("\n") if body.strip() else []
    if span is None:
        if not body_lines:
            return text
        base = text.rstrip("\n")
        block = "\n".join([begin] + body_lines + [end])
        return (f"{base}\n\n{block}" if base else block) + "\n"
    b, e = span
    if body_lines:
        return "\n".join(lines[:b] + [begin] + body_lines + [end] + lines[e + 1:])
    before, after = lines[:b], lines[e + 1:]
    if before and before[-1] == "":
        before = before[:-1]  # the blank line setup put in front of the block
    return "\n".join(before + after)


def cmd_block(path, comment, body):
    text, crlf = read(path)
    commit(path, text, replace_block(path, text, comment, body), crlf)


def cmd_has_block(path, comment):
    text, _ = read(path)
    _, _, span = check_markers(path, text.split("\n"), comment)
    sys.exit(0 if span else 1)


# --- Solaar key diversion -----------------------------------------------------

def parse_flow(path, inner):
    pairs = {}
    for item in inner.split(","):
        item = item.strip()
        if not item:
            continue
        if ":" not in item:
            raise Refuse(4, f"{path}: divert-keys entry '{item}' is not 'id: value'; left unchanged")
        k, v = item.split(":", 1)
        pairs[parse_id(path, k)] = v.strip()
    return pairs


def parse_id(path, raw):
    try:
        return int(raw.strip())
    except ValueError:
        raise Refuse(4, f"{path}: divert-keys has a key '{raw.strip()}' that is not a number; left unchanged")


def set_diversion(path, text, device, value, ids):
    lines = text.split("\n")
    name_re = re.compile(r"^- _NAME:\s*(.*?)\s*$")
    starts = [i for i, line in enumerate(lines) if (m := name_re.match(line)) and m.group(1) == device]
    if not starts:
        raise Refuse(3, f"{path} has no saved entry for \"{device}\"")
    for start in reversed(starts):
        stop = start + 1
        # The entry runs until the next top-level line ("- _NAME: ...", "- 1.1.20", ...).
        while stop < len(lines) and lines[stop][:1] in ("", " ", "\t"):
            stop += 1
        found = None
        for k in range(start + 1, stop):
            m = re.match(r"^(\s+)divert-keys:\s*(.*?)\s*$", lines[k])
            if m:
                found = (k, m.group(1), m.group(2))
                break
        if found is None:
            pairs, first, last, indent = {}, None, None, "  "
        else:
            first, indent, rest = found
            if rest.startswith("{"):
                flow, last = rest, first
                while "}" not in flow:
                    last += 1
                    if last >= stop:
                        raise Refuse(4, f"{path}: divert-keys for \"{device}\" has no closing '}}'; left unchanged")
                    flow += " " + lines[last].strip()
                pairs = parse_flow(path, flow[1:flow.index("}")])
            elif rest == "":
                pairs, last = {}, first
                while last + 1 < stop and len(lines[last + 1]) - len(lines[last + 1].lstrip()) > len(indent) \
                        and lines[last + 1].strip():
                    last += 1
                    m = re.match(r"^\s+([^:]+):\s*(.*?)\s*$", lines[last])
                    if not m:
                        raise Refuse(4, f"{path}: cannot read divert-keys line '{lines[last].strip()}'; left unchanged")
                    pairs[parse_id(path, m.group(1))] = m.group(2)
            else:
                raise Refuse(4, f"{path}: divert-keys for \"{device}\" is not a mapping; left unchanged")
        for i in ids:
            pairs[i] = str(value)
        flow_line = f"{indent}divert-keys: {{" + ", ".join(f"{k}: {v}" for k, v in sorted(pairs.items())) + "}"
        if first is None:
            at = stop
            while at > start + 1 and lines[at - 1] == "":
                at -= 1
            lines[at:at] = [flow_line]
        else:
            lines[first:last + 1] = [flow_line]
    return "\n".join(lines)


def cmd_divert(path, device, value, ids):
    if not os.path.exists(path):
        raise Refuse(3, f"{path} does not exist yet")
    text, crlf = read(path)
    commit(path, text, set_diversion(path, text, device, int(value), [int(i) for i in ids]), crlf)


# --- Solaar rules -------------------------------------------------------------

def plugin_command(key, show_desktop):
    for name, _, command in RULES:
        if name == key:
            return [show_desktop] if command is None else command
    return None


def rules_body(show_desktop):
    out = ["# Logitech POP Icon Keys top row -> Omarchy. Managed by the pop-icon-keys plugin;",
           "# re-running its setup replaces this block, its uninstall removes it."]
    for name, comment, command in RULES:
        command = [show_desktop] if command is None else command
        out += ["---", f"# {comment}", f"- Key: [{name}, pressed]", f"- Execute: [{', '.join(command)}]", "..."]
    return "\n".join(out)


def documents(lines, skip):
    """Yield (first, last, text) for each '---' ... '...' YAML document outside SKIP (a line range)."""
    i = 0
    while i < len(lines):
        if skip and skip[0] <= i <= skip[1]:
            i = skip[1] + 1
            continue
        if lines[i].rstrip() == "---":
            j = i + 1
            while j < len(lines) and lines[j].rstrip() not in ("...", "---"):
                j += 1
            last = j if j < len(lines) and lines[j].rstrip() == "..." else j - 1
            yield i, last, "\n".join(lines[i + 1:j])
            i = last + 1
        else:
            i += 1


def classify(doc, show_desktop):
    """Return ('plugin', key) for a rule identical to one this plugin writes,
    ('other', key) for any other rule on one of its keys, or (None, None)."""
    try:
        import yaml
        data = yaml.safe_load(doc)
    except Exception:
        return None, None
    if not isinstance(data, list):
        return None, None
    key = None
    for part in data:
        if isinstance(part, dict) and isinstance(part.get("Key"), list) and part["Key"]:
            if part["Key"][0] in [r[0] for r in RULES]:
                key = part["Key"][0]
    if key is None:
        return None, None
    if len(data) == 2 and data[0] == {"Key": [key, "pressed"]} and isinstance(data[1], dict) \
            and list(data[1]) == ["Execute"]:
        command = data[1]["Execute"]
        command = [command] if isinstance(command, str) else command
        want = plugin_command(key, show_desktop)
        if command == want or (key == "Show Desktop" and len(command) == 1
                               and os.path.basename(str(command[0])) == SHOW_DESKTOP_NAME):
            return "plugin", key
    return "other", key


def scan_rules(path, show_desktop):
    text, crlf = read(path)
    lines = text.split("\n")
    _, _, span = check_markers(path, lines, "#")
    found = []
    for first, last, doc in documents(lines, span):
        kind, key = classify(doc, show_desktop)
        if kind:
            found.append((kind, key, first, last))
    return text, crlf, lines, found


def cmd_rules_scan(path, show_desktop):
    """Print 'plugin <key>' / 'other <key>' for each rule on the plugin's keys outside its block."""
    _, _, _, found = scan_rules(path, show_desktop)
    for kind, key, _, _ in found:
        print(f"{kind}\t{key}")


def cmd_rules_drop_copies(path, show_desktop):
    """Remove rules outside the block that are exact copies of this plugin's rules."""
    text, crlf, lines, found = scan_rules(path, show_desktop)
    for kind, key, first, last in reversed(found):
        if kind == "plugin":
            print(f"  removing an earlier copy of the {key} rule (lines {first + 1}-{last + 1})")
            del lines[first:last + 1]
    commit(path, text, "\n".join(lines), crlf)


def main(argv):
    if not argv:
        raise SystemExit("usage: edit.py <command> ...")
    command, args = argv[0], argv[1:]
    try:
        if command == "block":
            cmd_block(args[0], args[1], sys.stdin.read())
        elif command == "has-block":
            cmd_has_block(args[0], args[1])
        elif command == "divert":
            cmd_divert(args[0], args[1], args[2], args[3:])
        elif command == "rules-body":
            print(rules_body(args[0]))
        elif command == "rules-scan":
            cmd_rules_scan(args[0], args[1])
        elif command == "rules-drop-copies":
            cmd_rules_drop_copies(args[0], args[1])
        else:
            raise SystemExit(f"edit.py: unknown command {command}")
    except Refuse as e:
        print(f"{'note' if e.code == 3 else 'error'}: {e}", file=sys.stderr)
        sys.exit(e.code)


if __name__ == "__main__":
    main(sys.argv[1:])
