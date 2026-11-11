"""Fill in Lutris cover art for installed games that have none.

Moonshine's Lutris scanner (and Lutris itself) shows
~/.local/share/lutris/coverart/<slug>.{jpg,png}. For each installed game
missing one, in order:

1. Reuse the cover Helios has for that game: an apps.json entry that runs
   `lutris lutris:rungameid/<id>`, or has the same name.
2. Look the game up by exact name in LizardByte's GameDB (the IGDB mirror
   Helios's cover finder uses) and download its IGDB cover.

Games with no exact-name match are reported and left alone; put an image at
the printed path by hand. Existing covers are never replaced unless --force
is given.
"""

import argparse
import json
import os
import re
import shutil
import sqlite3
import sys
import urllib.request
from pathlib import Path

GAMEDB = "https://raw.githubusercontent.com/LizardByte/GameDB/gh-pages"
IGDB = "https://images.igdb.com/igdb/image/upload/t_cover_big_2x/{}.png"
USER_AGENT = "lutris-covers"


def data_home():
    return Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share")


def config_home():
    return Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")


def normalize(name):
    name = name.lower().replace("&", "and")
    return re.sub(r"[^a-z0-9]", "", name)


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=20) as response:
        return response.read()


def installed_games(pga_db):
    uri = f"file:{pga_db}?mode=ro"
    with sqlite3.connect(uri, uri=True, timeout=5) as conn:
        rows = conn.execute(
            "SELECT id, name, slug FROM games WHERE installed = 1 ORDER BY name"
        )
        return rows.fetchall()


def helios_covers():
    """Cover paths from Helios's apps.json, by Lutris id and by name."""
    apps_json = config_home() / "helios/apps.json"
    by_id, by_name = {}, {}
    try:
        apps = json.loads(apps_json.read_text())["apps"]
    except (OSError, ValueError, KeyError):
        return by_id, by_name
    for app in apps:
        image = app.get("image-path")
        if not image or not Path(image).is_file():
            continue
        match = re.fullmatch(r"lutris lutris:rungameid/(\d+)", app.get("cmd", ""))
        if match:
            by_id[int(match.group(1))] = Path(image)
        by_name[normalize(app.get("name", ""))] = Path(image)
    return by_id, by_name


def bucket_for(name):
    bucket = re.sub(r"[^a-z0-9]", "", name[:2].lower())
    return bucket or "@"


def gamedb_cover(name, buckets):
    """IGDB cover URL for the GameDB game named exactly `name`, or None."""
    bucket = bucket_for(name)
    if bucket not in buckets:
        buckets[bucket] = json.loads(fetch(f"{GAMEDB}/buckets/{bucket}.json"))
    wanted = normalize(name)
    # Lowest id first: with several exact matches, usually the original game.
    ids = sorted(
        (int(game_id) for game_id, entry in buckets[bucket].items()
         if normalize(entry.get("name", "")) == wanted),
    )
    for game_id in ids:
        game = json.loads(fetch(f"{GAMEDB}/games/{game_id}.json"))
        url = (game.get("cover") or {}).get("url", "")
        image = url.rsplit("/", 1)[-1].rsplit(".", 1)[0]
        if image:
            return IGDB.format(image)
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--force", action="store_true", help="replace existing covers"
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="report without writing"
    )
    args = parser.parse_args()

    lutris = data_home() / "lutris"
    pga_db = lutris / "pga.db"
    coverart = lutris / "coverart"
    if not pga_db.is_file():
        print(f"No Lutris database at {pga_db}", file=sys.stderr)
        return 1

    by_id, by_name = helios_covers()
    buckets = {}
    missing = 0
    for game_id, name, slug in installed_games(pga_db):
        existing = [coverart / f"{slug}.{ext}" for ext in ("jpg", "png")]
        if not args.force and any(path.is_file() for path in existing):
            continue
        target = coverart / f"{slug}.png"

        source = by_id.get(game_id) or by_name.get(normalize(name))
        if source:
            print(f"{name}: Helios cover {source.name}")
            if not args.dry_run:
                coverart.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, target)
            continue

        try:
            url = gamedb_cover(name, buckets)
        except (OSError, ValueError) as error:
            print(f"{name}: GameDB lookup failed: {error}", file=sys.stderr)
            missing += 1
            continue
        if not url:
            print(f"{name}: no exact match in GameDB; add {target} by hand")
            missing += 1
            continue
        print(f"{name}: IGDB cover {url}")
        if not args.dry_run:
            coverart.mkdir(parents=True, exist_ok=True)
            data = fetch(url)
            tmp = target.with_suffix(".png.tmp")
            tmp.write_bytes(data)
            tmp.replace(target)

    if missing:
        print(f"{missing} game(s) still without a cover", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
