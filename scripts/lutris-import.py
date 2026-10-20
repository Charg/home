#!/usr/bin/env python3
"""Import Windows games installed on the NTFS drives into Lutris.

Each folder under the given roots is treated as one game. The script picks
the most likely game executable, then creates the same two things Lutris'
"Add locally installed game" dialog does: a games/<configpath>.yml and a row
in pga.db. Every game gets its own prefix under ~/Games/<slug> and uses the
default Wine runner version (GE-Proton via umu).

Folders whose executable is already in Lutris are skipped, so re-running only
picks up new games. Without --apply it only prints what it would do.

Usage: lutris-import.py [--apply] [--yes] [--include-store] [ROOT ...]
"""

import argparse
import math
import os
import re
import sqlite3
import sys
import time
from pathlib import Path

LUTRIS_DIR = Path.home() / ".local/share/lutris"
DEFAULT_ROOTS = ["/mnt/extras/Games", "/mnt/windows/Games"]
PREFIX_ROOT = Path.home() / "Games"

MAX_DEPTH = 4
MIN_EXE_SIZE = 500 * 1024

# Executables that ship alongside games but are never the game itself.
EXCLUDE_EXE = re.compile(
    r"unins|crash|redist|setup|vc_?redist|dxsetup|directx|installer|"
    r"easyanticheat|battleye|prereq|cefprocess|helper|report|dotnet|"
    r"activation|cleanup|touchup|crs-|uploader|repair|artbook|editor|"
    r"texconv|burner|webclient|starweb|switcher|redmod|^scc$|_be$",
    re.IGNORECASE,
)
LAUNCHER_EXE = re.compile(r"launcher", re.IGNORECASE)

# Files that mark a folder as owned by a store client. Launching these games'
# executables directly fails because the client handles DRM/login; install
# them through Lutris' matching source (or the client in a prefix) instead.
STORE_MARKERS = {
    ".build.info": "the Battle.net app",
    "microsoftgame.config": "the Xbox app",
    "__installer": "the EA app",
}


def tokens(text):
    return set(re.findall(r"[a-z0-9]+", text.lower()))


def compact(text):
    return re.sub(r"[^a-z0-9]", "", text.lower())


def display_name(folder):
    # Windows forbids ':' in folder names, so "Foo - Bar" is usually "Foo: Bar".
    name = re.sub(r"\s*\[[^\]]*\]", "", folder).strip()
    return name.replace(" - ", ": ")


def slugify(name):
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")


def store_of(game_dir):
    entries = {p.name.lower() for p in game_dir.iterdir()}
    for marker, store in STORE_MARKERS.items():
        if marker in entries:
            return store
    return None


def candidates(game_dir):
    found = []
    for dirpath, dirnames, filenames in os.walk(game_dir):
        depth = len(Path(dirpath).relative_to(game_dir).parts)
        # Skip redistributable/installer/update folders (_Redist, __Installer, ...).
        dirnames[:] = [
            d for d in dirnames if depth < MAX_DEPTH and not d.startswith(("_", "."))
        ]
        for filename in filenames:
            path = Path(dirpath) / filename
            if path.suffix.lower() != ".exe" or EXCLUDE_EXE.search(path.stem):
                continue
            try:
                size = path.stat().st_size
            except OSError:
                continue
            if size >= MIN_EXE_SIZE:
                found.append((path, depth, size))
    return found


def score(game_dir, path, depth, size):
    folder, stem = game_dir.name, path.stem
    similarity = 10 * len(tokens(folder) & tokens(stem))
    if compact(stem) and (compact(stem) in compact(folder) or compact(folder) in compact(stem)):
        similarity += 15
    penalty = 20 if LAUNCHER_EXE.search(stem) else 0
    return similarity + math.log2(size) - 2 * depth - penalty


def ranked(game_dir):
    scored = [(score(game_dir, *c), c[0]) for c in candidates(game_dir)]
    return [path for _, path in sorted(scored, key=lambda s: s[0], reverse=True)]


def choose(game_dir, options, interactive):
    if len(options) == 1 or not interactive:
        return options[0]
    print(f"\n{game_dir}")
    for i, path in enumerate(options[:8], 1):
        print(f"  {i}) {path.relative_to(game_dir)}")
    while True:
        answer = input("  Executable [1, s=skip]: ").strip().lower()
        if answer == "":
            return options[0]
        if answer == "s":
            return None
        if answer.isdigit() and 1 <= int(answer) <= min(len(options), 8):
            return options[int(answer) - 1]


def imported_exes():
    exes = set()
    for config in (LUTRIS_DIR / "games").glob("*.yml"):
        match = re.search(r"^\s+exe:\s*(.+)$", config.read_text(), re.MULTILINE)
        if match:
            exes.add(Path(match.group(1).strip().strip("'\"")))
    return exes


def yaml_str(value):
    # JSON-style double-quoted strings are valid YAML and survive spaces,
    # apostrophes and brackets in Windows folder names.
    return '"' + str(value).replace("\\", "\\\\").replace('"', '\\"') + '"'


def add_game(db, name, slug, exe, prefix, game_dir):
    now = int(time.time())
    configpath = f"{slug}-{now}"
    (LUTRIS_DIR / "games" / f"{configpath}.yml").write_text(
        f"game:\n  exe: {yaml_str(exe)}\n  prefix: {yaml_str(prefix)}\n"
    )
    db.execute(
        """INSERT INTO games (name, slug, platform, runner, directory, installed,
                              installed_at, configpath, has_custom_banner,
                              has_custom_icon, has_custom_coverart_big, playtime)
           VALUES (?, ?, 'Windows', 'wine', ?, 1, ?, ?, 0, 0, 0, 0)""",
        (name, slug, str(game_dir), now, configpath),
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("roots", nargs="*", default=DEFAULT_ROOTS)
    parser.add_argument("--apply", action="store_true", help="write to Lutris (default: dry run)")
    parser.add_argument("--yes", action="store_true", help="take the best-guess executable without asking")
    parser.add_argument("--include-store", action="store_true", help="also import Battle.net/Xbox/EA games")
    args = parser.parse_args()

    db_path = LUTRIS_DIR / "pga.db"
    if not db_path.exists():
        sys.exit(f"{db_path} not found; start Lutris once first")
    db = sqlite3.connect(db_path)
    slugs = {row[0] for row in db.execute("SELECT slug FROM games")}
    existing = imported_exes()
    interactive = args.apply and not args.yes and sys.stdin.isatty()

    added, skipped = [], []
    for root in map(Path, args.roots):
        if not root.is_dir():
            skipped.append((root, "root not found"))
            continue
        for game_dir in sorted(p for p in root.iterdir() if p.is_dir()):
            if any(game_dir in exe.parents for exe in existing):
                skipped.append((game_dir, "already in Lutris"))
                continue
            store = store_of(game_dir)
            if store and not args.include_store:
                skipped.append((game_dir, f"needs {store}"))
                continue
            options = ranked(game_dir)
            if not options:
                skipped.append((game_dir, "no game executable found"))
                continue
            exe = choose(game_dir, options, interactive)
            if exe is None:
                skipped.append((game_dir, "skipped"))
                continue

            name = display_name(game_dir.name)
            slug = base = slugify(name)
            n = 2
            while slug in slugs:
                slug, n = f"{base}-{n}", n + 1
            slugs.add(slug)
            prefix = PREFIX_ROOT / slug

            if args.apply:
                add_game(db, name, slug, exe, prefix, game_dir)
            added.append((name, exe))

    if args.apply:
        db.commit()
    db.close()

    verb = "Imported" if args.apply else "Would import"
    print(f"\n{verb} {len(added)} game(s):")
    for name, exe in added:
        print(f"  {name}\n    {exe}")
    if skipped:
        print(f"\nSkipped {len(skipped)}:")
        for path, reason in skipped:
            print(f"  {path}  ({reason})")
    if not args.apply:
        print("\nDry run. Re-run with --apply to write to Lutris (you'll be asked to")
        print("confirm the executable for folders with more than one candidate).")
    elif added:
        print("\nRestart Lutris to see the new games.")


if __name__ == "__main__":
    main()
