#!/usr/bin/env python3
"""omacase usage — agent token burn + plan limits for Claude, Codex, and Grok.

Follows Omarchy Quattro's collector shape: each provider yields one
display-ready JSON record in ~/.local/state/omacase/usage/<agent>.json, and the
renderer only reads those records. Sources:

  claude  ~/.claude/projects/**/*.jsonl   per-message usage tokens
          Keychain "Claude Code-credentials" OAuth token ->
          https://api.anthropic.com/api/oauth/usage      plan limit windows
  codex   ~/.codex/sessions/**/*.jsonl    token_count events: cumulative
          total_token_usage (delta per event) + rate_limits (local, no API)
  grok    ~/.grok/sessions/*/*/updates.jsonl  cumulative _meta.totalTokens per
          session (approximate; Grok exposes no limit data)

Colors are plain ANSI indices so charts track the active Ghostty theme.
"""

import datetime as dt
import fcntl
import json
import os
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
from pathlib import Path

STATE_DIR = Path(os.environ.get("OMACASE_STATE", Path.home() / ".local/state/omacase")) / "usage"
SCAN_WINDOW_DAYS = 8
CLAUDE_USAGE_ENDPOINT = "https://api.anthropic.com/api/oauth/usage"

RESET = "\033[0m"
BOLD = "\033[1m"
DIM = "\033[2m"
FG = {"claude": "\033[35m", "codex": "\033[36m", "grok": "\033[33m"}
BAR_FG = {"claude": "\033[95m", "codex": "\033[96m", "grok": "\033[93m"}
BLOCKS = " ▁▂▃▄▅▆▇█"


def day_str(ts: dt.datetime) -> str:
    return ts.astimezone().strftime("%Y-%m-%d")


def recent_days(n: int = 7) -> list:
    today = dt.date.today()
    return [(today - dt.timedelta(days=i)).strftime("%Y-%m-%d") for i in range(n - 1, -1, -1)]


def parse_ts(value):
    if not isinstance(value, str):
        return None
    try:
        return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def fresh_files(root: Path, pattern: str) -> list:
    if not root.is_dir():
        return []
    cutoff = dt.datetime.now().timestamp() - SCAN_WINDOW_DAYS * 86400
    out = []
    for f in root.rglob(pattern):
        try:
            if f.stat().st_mtime >= cutoff:
                out.append(f)
        except OSError:
            continue
    return out


def bucket_add(days: dict, day: str, model: str, tokens: int):
    b = days.setdefault(day, {"total": 0, "models": {}})
    b["total"] += tokens
    b["models"][model] = b["models"].get(model, 0) + tokens


# --- claude ------------------------------------------------------------------

def collect_claude() -> dict:
    days: dict = {}
    seen = set()
    for f in fresh_files(Path.home() / ".claude/projects", "*.jsonl"):
        try:
            with f.open(errors="replace") as fh:
                for line in fh:
                    if '"usage"' not in line:
                        continue
                    try:
                        row = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    msg = row.get("message") or {}
                    usage = msg.get("usage") or {}
                    if row.get("type") != "assistant" or not usage:
                        continue
                    key = (msg.get("id"), row.get("requestId"))
                    if key in seen:
                        continue
                    seen.add(key)
                    ts = parse_ts(row.get("timestamp"))
                    if not ts:
                        continue
                    total = sum(int(usage.get(k) or 0) for k in (
                        "input_tokens", "output_tokens",
                        "cache_read_input_tokens", "cache_creation_input_tokens"))
                    bucket_add(days, day_str(ts), str(msg.get("model") or "unknown"), total)
        except OSError:
            continue
    record = {"agent": "claude", "name": "Claude Code", "days": days}
    record.update(claude_limits())
    return record


def claude_limits() -> dict:
    try:
        token = subprocess.run(
            ["security", "find-generic-password", "-s", "Claude Code-credentials", "-w"],
            capture_output=True, text=True, timeout=10).stdout.strip()
        login = json.loads(token).get("claudeAiOauth") or {}
        access = login.get("accessToken")
        if not access:
            return {"limits": [], "note": "not logged in (claude auth login)"}
        plan = str(login.get("subscriptionType") or login.get("rateLimitTier") or "")
    except Exception:
        return {"limits": [], "note": "keychain unavailable"}
    req = urllib.request.Request(CLAUDE_USAGE_ENDPOINT, headers={
        "Authorization": "Bearer " + access,
        "anthropic-beta": "oauth-2025-04-20",
        "Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            payload = json.loads(resp.read().decode("utf-8", errors="replace"))
    except urllib.error.HTTPError as e:
        return {"plan": plan, "limits": [], "note": f"usage endpoint HTTP {e.code}"}
    except Exception:
        return {"plan": plan, "limits": [], "note": "usage endpoint unreachable"}
    windows = [("5-hour", payload.get("five_hour")),
               ("weekly", payload.get("seven_day_oauth_apps") or payload.get("seven_day"))]
    # One payload speaks one convention: fractions (0-1) or percents (0-100).
    raw = [w.get("utilization") for _, w in windows if isinstance(w, dict)]
    is_percent = any(isinstance(v, (int, float)) and v > 1 for v in raw)
    limits = []
    for label, window in windows:
        if not isinstance(window, dict) or window.get("utilization") is None:
            continue
        pct = float(window["utilization"])
        limits.append({
            "label": label,
            "used_percent": pct if is_percent else pct * 100,
            "resets_at": window.get("resets_at")})
    return {"plan": plan, "limits": limits}


# --- codex -------------------------------------------------------------------

def collect_codex() -> dict:
    days: dict = {}
    latest_limits, latest_ts = None, None
    for f in fresh_files(Path.home() / ".codex/sessions", "*.jsonl"):
        prev = 0
        try:
            with f.open(errors="replace") as fh:
                for line in fh:
                    if '"token_count"' not in line:
                        continue
                    try:
                        row = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    payload = row.get("payload") or {}
                    if payload.get("type") != "token_count":
                        continue
                    ts = parse_ts(row.get("timestamp"))
                    info = payload.get("info") or {}
                    totals = info.get("total_token_usage") or payload.get("total_token_usage") or {}
                    cur = int(totals.get("total_tokens") or 0)
                    if cur and ts:
                        delta = cur - prev if cur >= prev else cur
                        prev = cur
                        if delta:
                            bucket_add(days, day_str(ts), "codex", delta)
                    rl = payload.get("rate_limits") or info.get("rate_limits")
                    if rl and ts and (latest_ts is None or ts > latest_ts):
                        latest_limits, latest_ts = rl, ts
        except OSError:
            continue
    limits = []
    if latest_limits:
        for key, fallback in (("primary", "window"), ("secondary", "window")):
            win = latest_limits.get(key)
            if not isinstance(win, dict) or win.get("used_percent") is None:
                continue
            minutes = int(win.get("window_minutes") or 0)
            label = "5-hour" if minutes == 300 else "weekly" if minutes == 10080 else (
                f"{minutes}m" if minutes else fallback)
            limits.append({
                "label": label,
                "used_percent": float(win["used_percent"]),
                "resets_at": win.get("resets_at"),
                "as_of": latest_ts.isoformat()})
    return {"agent": "codex", "name": "Codex", "days": days, "limits": limits,
            "note": None if limits else "no rate_limit events found"}


# --- grok --------------------------------------------------------------------

def collect_grok() -> dict:
    days: dict = {}
    root = Path.home() / ".grok/sessions"
    for f in fresh_files(root, "updates.jsonl"):
        peak, ts = 0, None
        try:
            with f.open(errors="replace") as fh:
                for line in fh:
                    if '"totalTokens"' not in line:
                        continue
                    try:
                        row = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    meta = (row.get("params") or {}).get("_meta") or {}
                    tok = int(meta.get("totalTokens") or 0)
                    peak = max(peak, tok)
                    ts = parse_ts(row.get("params", {}).get("timestamp")) or ts
        except OSError:
            continue
        if peak:
            when = ts or dt.datetime.fromtimestamp(f.stat().st_mtime).astimezone()
            model = "grok"
            summary = f.parent / "summary.json"
            try:
                model = json.loads(summary.read_text()).get("current_model_id") or model
            except Exception:
                pass
            bucket_add(days, day_str(when), model, peak)
    return {"agent": "grok", "name": "Grok", "days": days, "limits": [],
            "note": "session peaks (approximate); Grok exposes no limit data"}


# --- collection --------------------------------------------------------------

COLLECTORS = {"claude": collect_claude, "codex": collect_codex, "grok": collect_grok}


def _cleanup_stale_tmps():
    cutoff = dt.datetime.now().timestamp() - 3600
    for tmp in STATE_DIR.glob(".*.tmp"):
        try:
            if tmp.stat().st_mtime < cutoff:
                tmp.unlink()
        except OSError:
            pass


def _write_record(agent: str, record: dict):
    fd, tmp = tempfile.mkstemp(dir=STATE_DIR, prefix=f".{agent}.", suffix=".tmp")
    try:
        with os.fdopen(fd, "w") as fh:
            fh.write(json.dumps(record, indent=1) + "\n")
        # No fsync: records are regenerable cache; durability is not worth the cost.
        os.replace(tmp, STATE_DIR / f"{agent}.json")
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def collect(agents=None, max_age=None):
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    with open(STATE_DIR / ".collect.lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)  # collections take ~1s; blocking is fine
        if max_age is not None and state_age_seconds() <= max_age:
            return  # the holder we waited on just refreshed
        _cleanup_stale_tmps()
        for agent, fn in COLLECTORS.items():
            if agents and agent not in agents:
                continue
            try:
                record = fn()
            except Exception as e:  # a broken provider must not block the others
                record = {"agent": agent, "name": agent, "days": {}, "limits": [],
                          "note": f"collector failed: {e}"}
            record["collected_at"] = dt.datetime.now().astimezone().isoformat()
            _write_record(agent, record)


def state_age_seconds() -> float:
    ages = []
    for agent in COLLECTORS:
        f = STATE_DIR / f"{agent}.json"
        try:
            ages.append(dt.datetime.now().timestamp() - f.stat().st_mtime)
        except OSError:
            return float("inf")
    return max(ages) if ages else float("inf")


# --- rendering ---------------------------------------------------------------

def human(n: float) -> str:
    for unit, div in (("B", 1e9), ("M", 1e6), ("K", 1e3)):
        if n >= div:
            return f"{n / div:.1f}{unit}"
    return str(int(n))


def gauge(pct: float, width: int, color: str) -> str:
    pct = max(0.0, min(100.0, pct))
    filled = int(round(pct / 100 * width))
    return color + "█" * filled + RESET + DIM + "░" * (width - filled) + RESET


def spark_column(value: float, peak: float) -> str:
    if peak <= 0:
        return BLOCKS[0]
    return BLOCKS[max(0, min(8, round(value / peak * 8)))]


def reset_eta(resets_at) -> str:
    if not resets_at:
        return ""
    try:
        when = dt.datetime.fromtimestamp(float(resets_at)).astimezone() \
            if isinstance(resets_at, (int, float)) or str(resets_at).isdigit() \
            else parse_ts(str(resets_at))
    except Exception:
        return ""
    if not when:
        return ""
    delta = when - dt.datetime.now().astimezone()
    mins = int(delta.total_seconds() // 60)
    if mins <= 0:
        return "resets now"
    if mins < 60:
        return f"resets {mins}m"
    if mins < 2880:
        return f"resets {mins // 60}h{mins % 60:02d}m"
    return f"resets {mins // 1440}d"


def render(width: int = 66):
    days_axis = recent_days(7)

    def row(fg: str, colored: str, plain: str):
        pad = " " * max(0, width - 2 - len(plain))
        print(f"{fg}│{RESET}{colored}{pad}{fg}│{RESET}")

    print()
    for agent in COLLECTORS:
        f = STATE_DIR / f"{agent}.json"
        try:
            rec = json.loads(f.read_text())
        except Exception:
            print(f"{FG.get(agent, '')}{BOLD}{agent}{RESET}  {DIM}no data — run `omacase usage update`{RESET}\n")
            continue
        fg, bar = FG.get(agent, ""), BAR_FG.get(agent, "")
        days = rec.get("days") or {}
        series = [days.get(d, {}).get("total", 0) for d in days_axis]
        peak = max(series) if series else 0
        today = series[-1] if series else 0
        week = sum(series)

        title = f" {rec.get('name', agent)} "
        plan = rec.get("plan") or ""
        plan_txt = f" {DIM}{plan}{RESET}" if plan else ""
        pad = width - len(title) - 3
        print(f"{fg}┌─{BOLD}{title}{RESET}{fg}{'─' * max(0, pad)}┐{RESET}{plan_txt}")

        # 7-day sparkline, 4 columns per day.
        cells = "".join(spark_column(v, peak) * 4 for v in series)
        stats = f"  today {human(today)} · 7d {human(week)}"
        row(fg, f" {bar}{cells}{RESET}  today {BOLD}{human(today)}{RESET} · 7d {human(week)}",
            f" {cells}{stats}")
        axis = "".join(d[8:] + "  " for d in days_axis)
        row(fg, f" {DIM}{axis}{RESET}", f" {axis}")

        # Today's top models.
        models = (days.get(days_axis[-1]) or {}).get("models") or {}
        bar_w = 24
        for model, tok in sorted(models.items(), key=lambda kv: -kv[1])[:3]:
            frac = tok / today if today else 0
            filled = int(round(frac * bar_w))
            name = model[:24]
            row(fg, f" {name:<24} {bar}{'▓' * filled}{RESET}{DIM}{'░' * (bar_w - filled)}{RESET} {human(tok):>7}",
                f" {name:<24} {'x' * bar_w} {human(tok):>7}")

        # Limit gauges.
        for lim in rec.get("limits") or []:
            pct = lim.get("used_percent", 0.0)
            eta = reset_eta(lim.get("resets_at"))
            row(fg, f" {lim.get('label', ''):<8} {gauge(pct, bar_w, bar)} {pct:5.1f}%  {DIM}{eta}{RESET}",
                f" {lim.get('label', ''):<8} {'x' * bar_w} {pct:5.1f}%  {eta}")

        note = rec.get("note")
        if note:
            note = note[:width - 4]
            row(fg, f" {DIM}{note}{RESET}", f" {note}")
        print(f"{fg}└{'─' * (width - 2)}┘{RESET}")
        print()
    age = state_age_seconds()
    if age != float("inf"):
        print(f"{DIM}collected {int(age // 60)}m ago — refresh: omacase usage update · "
              f"background: omacase extras usage-tracker on{RESET}")


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "show"
    if cmd == "update":
        collect(sys.argv[2:] or None)
    elif cmd == "show":
        if state_age_seconds() > 1800:
            collect(max_age=1800)
        render()
    elif cmd == "json":
        out = {}
        for agent in COLLECTORS:
            try:
                out[agent] = json.loads((STATE_DIR / f"{agent}.json").read_text())
            except Exception:
                out[agent] = None
        print(json.dumps(out, indent=1))
    else:
        print(f"unknown usage subcommand: {cmd}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
