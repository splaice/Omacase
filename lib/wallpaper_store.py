"""Point every macOS desktop wallpaper entry at one image.

Usage: python3 -I wallpaper_store.py <image> [Index.plist]

System Events' `set picture of every desktop` only reaches the current Space
on each display that is connected right now. macOS (Sonoma+) keeps a separate
choice for every Space x display it has ever seen, plus a SystemDefault used
for displays it hasn't met yet, in WallpaperAgent's store. We rewrite every
Desktop choice there so an external monitor plugged in later (or a Space not
visited since the last theme switch) shows the same picture. The caller
restarts WallpaperAgent so it re-reads the store.
"""

import datetime
import os
import plistlib
import sys
import tempfile
import urllib.parse

DEFAULT_STORE = os.path.expanduser(
    "~/Library/Application Support/com.apple.wallpaper/Store/Index.plist"
)


def choice(url):
    config = plistlib.dumps(
        {"type": "imageFile", "url": {"relative": url}}, fmt=plistlib.FMT_BINARY
    )
    return {
        "Provider": "com.apple.wallpaper.choice.image",
        "Files": [],
        "Configuration": config,
    }


def desktop(url, now):
    return {
        "Content": {
            "Choices": [choice(url)],
            "Shuffle": "$null",
            "EncodedOptionValues": "$null",
        },
        "LastSet": now,
        "LastUse": now,
    }


def entries(store):
    """Yield every per-scope entry (a dict with Type/Desktop/Idle keys)."""
    for key in ("AllSpacesAndDisplays", "SystemDefault"):
        if isinstance(store.get(key), dict):
            yield store[key]
    for display in (store.get("Displays") or {}).values():
        yield display
    for space in (store.get("Spaces") or {}).values():
        if isinstance(space.get("Default"), dict):
            yield space["Default"]
        for display in (space.get("Displays") or {}).values():
            yield display


def main():
    image = os.path.abspath(sys.argv[1])
    path = sys.argv[2] if len(sys.argv) > 2 else DEFAULT_STORE
    if not os.path.isfile(path):
        return 0  # pre-Sonoma or never-set store: System Events already did it
    url = "file://" + urllib.parse.quote(image)
    now = datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)

    with open(path, "rb") as fh:
        store = plistlib.load(fh)

    # New displays inherit SystemDefault; make sure it exists.
    store.setdefault("SystemDefault", {"Type": "individual"})
    changed = 0
    for entry in entries(store):
        # AllSpacesAndDisplays is "idle" (screen saver only) unless the user
        # chose "Show on all Spaces"; give it a Desktop only if it has one.
        if "Desktop" in entry or entry is store["SystemDefault"]:
            entry["Desktop"] = desktop(url, now)
            entry.setdefault("Type", "individual")
            changed += 1

    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".Index.")
    with os.fdopen(fd, "wb") as fh:
        plistlib.dump(store, fh, fmt=plistlib.FMT_BINARY)
    os.chmod(tmp, 0o644)
    os.replace(tmp, path)
    print(changed)
    return 0


if __name__ == "__main__":
    sys.exit(main())
