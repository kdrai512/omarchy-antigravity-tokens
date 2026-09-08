#!/usr/bin/env python3
"""
Fetch live token quota and account details for Google Antigravity CLI.
Caches output in ~/.local/state/omarchy/antigravity/tokens.json
"""

import datetime
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

API_ENDPOINT = "https://daily-cloudcode-pa.googleapis.com/v1internal:fetchAvailableModels"
STATE_DIR = Path.home() / ".local" / "state" / "omarchy" / "antigravity"
STATE_FILE = STATE_DIR / "tokens.json"


def get_google_account() -> str:
    accounts_file = Path.home() / ".gemini" / "google_accounts.json"
    if accounts_file.is_file():
        try:
            data = json.loads(accounts_file.read_text())
            if data.get("active"):
                return data["active"]
            old = data.get("old", [])
            if old and isinstance(old, list):
                return old[0]
        except Exception:
            pass
    return "raikundan512@gmail.com"


def get_secret_credentials() -> dict:
    try:
        raw = subprocess.check_output(
            ["secret-tool", "lookup", "service", "gemini", "username", "antigravity"],
            stderr=subprocess.DEVNULL,
            timeout=5,
        ).decode("utf-8").strip()
        if raw:
            return json.loads(raw)
    except Exception:
        pass
    return {}


def discover_oauth_client_from_binary() -> tuple[str, str]:
    """Dynamically discover desktop OAuth client credentials from local Antigravity binary."""
    # Check environment overrides first
    env_cid = os.environ.get("ANTIGRAVITY_CLIENT_ID", "")
    env_sec = os.environ.get("ANTIGRAVITY_CLIENT_SECRET", "")
    if env_cid and env_sec:
        return env_cid, env_sec

    candidates = []
    found = shutil.which("antigravity") or shutil.which("agy")
    if found:
        candidates.append(Path(found).resolve())

    candidates.extend([
        Path.home() / ".local/share/mise/installs/agy/latest/antigravity",
        Path.home() / ".gemini/antigravity-cli/bin/antigravity",
        Path("/usr/local/bin/antigravity"),
        Path("/usr/bin/antigravity"),
    ])

    for p in candidates:
        if p.is_file() and os.access(p, os.R_OK):
            try:
                with open(p, "rb") as f:
                    data = f.read()
                cid_match = re.search(rb'[0-9]+-[a-z0-9_]+\.apps\.googleusercontent\.com', data)
                sec_match = re.search(rb'GOCSPX-[A-Za-z0-9_-]{28}', data)
                if cid_match and sec_match:
                    return cid_match.group(0).decode("utf-8"), sec_match.group(0).decode("utf-8")
            except Exception:
                continue

    return "", ""


def refresh_access_token(refresh_token: str) -> str:
    if not refresh_token:
        return ""
    client_id, client_secret = discover_oauth_client_from_binary()
    if not client_id or not client_secret:
        return ""
    data = urllib.parse.urlencode({
        "client_id": client_id,
        "client_secret": client_secret,
        "refresh_token": refresh_token,
        "grant_type": "refresh_token",
    }).encode("utf-8")
    req = urllib.request.Request("https://oauth2.googleapis.com/token", data=data)
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            body = json.loads(resp.read().decode("utf-8"))
            return body.get("access_token", "")
    except Exception:
        return ""


def call_models_api(access_token: str) -> dict:
    req = urllib.request.Request(
        API_ENDPOINT,
        headers={
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
            "User-Agent": "antigravity/1.1.26 linux/amd64",
        },
        data=json.dumps({"project": "default-cli-project"}).encode("utf-8"),
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read().decode("utf-8"))


def format_tokens(num: int) -> str:
    if num >= 1_000_000:
        return f"{num / 1_000_000:.2f}M"
    if num >= 1_000:
        return f"{num / 1_000:.0f}k"
    return str(num)


def format_duration(ms: float) -> str:
    if ms <= 0:
        return "now"
    minutes = int(ms // 60000)
    hours = int(minutes // 60)
    days = int(hours // 24)
    if days > 0:
        return f"{days}d {hours % 24}h"
    if hours > 0:
        return f"{hours}h {minutes % 60}m"
    return f"{max(1, minutes)}m"


def fetch_token_metrics() -> dict:
    account = get_google_account()
    creds = get_secret_credentials()
    token_obj = creds.get("token", {})
    access_token = token_obj.get("access_token", "")
    refresh_token = token_obj.get("refresh_token", "")

    if not access_token and not refresh_token:
        return {
            "ready": False,
            "error": "No Antigravity credentials in keyring",
            "account": account,
            "remainingFraction": 0,
            "remainingPercent": 0,
            "remainingTokens": 0,
            "maxTokens": 0,
            "formattedRemaining": "0",
            "formattedMax": "0",
            "resetTime": "",
            "resetIn": "",
            "models": [],
            "updatedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        }

    raw_data = None
    try:
        raw_data = call_models_api(access_token)
    except urllib.error.HTTPError as e:
        if e.code in (401, 403) and refresh_token:
            new_token = refresh_access_token(refresh_token)
            if new_token:
                access_token = new_token
                try:
                    raw_data = call_models_api(access_token)
                except Exception:
                    pass
    except Exception:
        pass

    if not raw_data:
        if STATE_FILE.is_file():
            try:
                cached = json.loads(STATE_FILE.read_text())
                cached["stale"] = True
                return cached
            except Exception:
                pass
        return {
            "ready": False,
            "error": "Unable to contact Antigravity API",
            "account": account,
            "remainingFraction": 0,
            "remainingPercent": 0,
            "remainingTokens": 0,
            "maxTokens": 0,
            "formattedRemaining": "0",
            "formattedMax": "0",
            "resetTime": "",
            "resetIn": "",
            "models": [],
            "updatedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        }

    models_map = raw_data.get("models", {})

    baseline_fraction = 1.0
    baseline_max_tokens = 1048576
    baseline_reset_time = ""

    parsed_models = []
    priority_order = [
        "gemini-3.8-flash-tiered",
        "gemini-3.1-pro-high",
        "gemini-2.5-flash",
        "gemini-2.5-pro",
        "claude-opus-4-6-thinking",
        "claude-sonnet-4-6",
        "gpt-oss-120b-medium",
    ]

    for model_id, info in models_map.items():
        quota = info.get("quotaInfo", {})
        fraction = float(quota.get("remainingFraction", 1.0))
        reset_time = quota.get("resetTime", "")
        max_tokens = int(info.get("maxTokens", 1048576))
        rem_tokens = int(max_tokens * fraction)

        name = info.get("label") or model_id
        if "gemini-3.8-flash" in model_id:
            name = "Gemini 3.8 Flash"
        elif "gemini-3.1-pro" in model_id:
            name = "Gemini 3.1 Pro"
        elif "gemini-2.5-flash" in model_id:
            name = "Gemini 2.5 Flash"
        elif "gemini-2.5-pro" in model_id:
            name = "Gemini 2.5 Pro"
        elif "claude-opus" in model_id:
            name = "Claude Opus 4.6"
        elif "claude-sonnet" in model_id:
            name = "Claude Sonnet 4.6"

        parsed_models.append({
            "id": model_id,
            "name": name,
            "remainingFraction": fraction,
            "remainingPercent": int(round(fraction * 100)),
            "remainingTokens": rem_tokens,
            "maxTokens": max_tokens,
            "formattedRemaining": format_tokens(rem_tokens),
            "formattedMax": format_tokens(max_tokens),
            "resetTime": reset_time,
        })

        if "gemini-3.8-flash" in model_id or (fraction < baseline_fraction and fraction > 0):
            baseline_fraction = fraction
            baseline_max_tokens = max_tokens
            if reset_time:
                baseline_reset_time = reset_time

    def sort_key(m):
        mid = m["id"]
        for idx, pref in enumerate(priority_order):
            if pref in mid:
                return (0, idx)
        return (1, m["name"])

    parsed_models.sort(key=sort_key)

    remaining_tokens = int(baseline_max_tokens * baseline_fraction)
    remaining_percent = int(round(baseline_fraction * 100))

    reset_in = ""
    if baseline_reset_time:
        try:
            target = datetime.datetime.fromisoformat(baseline_reset_time.replace("Z", "+00:00"))
            diff_ms = (target - datetime.datetime.now(datetime.timezone.utc)).total_seconds() * 1000
            reset_in = format_duration(diff_ms)
        except Exception:
            reset_in = ""

    result = {
        "ready": True,
        "account": account,
        "remainingFraction": baseline_fraction,
        "remainingPercent": remaining_percent,
        "remainingTokens": remaining_tokens,
        "maxTokens": baseline_max_tokens,
        "formattedRemaining": format_tokens(remaining_tokens),
        "formattedMax": format_tokens(baseline_max_tokens),
        "resetTime": baseline_reset_time,
        "resetIn": reset_in,
        "models": parsed_models[:8],
        "updatedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    }

    STATE_DIR.mkdir(parents=True, exist_ok=True)
    temp_file = STATE_DIR / ".tokens.tmp"
    temp_file.write_text(json.dumps(result, indent=2))
    temp_file.replace(STATE_FILE)

    return result


if __name__ == "__main__":
    res = fetch_token_metrics()
    print(json.dumps(res, indent=2))
