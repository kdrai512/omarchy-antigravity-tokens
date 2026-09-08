# Antigravity Tokens — Omarchy Shell Plugin

An [Omarchy](https://omarchy.org/) status bar widget and dropdown panel that tracks live remaining token quota, usage limits, and reset windows for the **Google Antigravity CLI** (`antigravity-cli` / `agy`).

---

## Features

- **Live Bar Indicator**:
  - Displays a clean status bar pill with the AI glyph (`✦`) and your current remaining token percentage.
  - Dynamically highlights in urgent theme color when remaining tokens drop below 15%.
  - Rich hover tooltip with full token readouts, Google account email, and time until window reset.

- **Detail Dropdown Panel**:
  - Drops down directly underneath the bar pill.
  - **Account Overview**: Shows your connected Google account.
  - **Available Token Gauge**: Large read-out of remaining vs. max tokens (e.g. `926k / 1.05M`), fuel-gauge progress bar, and rolling 5-hour window reset countdown.
  - **Model Breakdown**: Individual quotas for active models including Gemini 3.8 Flash, Gemini 3.1 Pro, Gemini 2.5 Flash/Pro, and Claude models.
  - **Instant Refresh**: Dedicated refresh action `↻` or middle/right-click directly on the bar pill.

- **Automatic Background Updates**:
  - Runs in the background every 5 minutes without interrupting your workflow.
  - Caches metrics locally in `~/.local/state/omarchy/antigravity/tokens.json`.

---

## Prerequisites

- **Omarchy Linux** with `omarchy-shell` (Quickshell)
- **Python 3**
- `secret-tool` (installed by default on Omarchy for Secret Service keyring integration)
- **Google Antigravity CLI** (`agy`) signed in to your Google account

---

## Installation

Install directly using the Omarchy plugin manager:

```bash
omarchy plugin add https://github.com/<your-username>/mrworld.antigravity-tokens.git --enable
```

Or manually clone into your Omarchy plugins directory:

```bash
git clone https://github.com/<your-username>/mrworld.antigravity-tokens.git ~/.config/omarchy/plugins/mrworld.antigravity-tokens
omarchy plugin enable mrworld.antigravity-tokens --section right
```

---

## Development & Validation

To test and validate the plugin folder against Omarchy's manifest schema:

```bash
omarchy plugin validate ./
```

To force-refresh the shell after making local edits:

```bash
omarchy restart shell
```

---

## License

MIT License
