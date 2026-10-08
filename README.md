# Linux Security Monitoring (bash + cron)

A small monitoring tool that detects **unexpected changes to system accounts** on a Linux server and warns the administrator. It started as a school exercise (Linux Server course, Odisee) and was then improved.

## Why

A new system account (UID below 1000) or a modified password entry that nobody planned is a classic sign of a compromise or a misconfiguration. Checking it by hand is easy to forget, so the check is automated and scheduled.

## How it works

1. **Baseline:** the script records the list of system users from `/etc/passwd` (extracted with `awk`) and a SHA-256 fingerprint of their entries in `/etc/shadow`.
2. **Check:** on each run it rebuilds the current state and compares it to the baseline (`diff` for the user list, fingerprint comparison for the password information).
3. **Alert:** if anything differs, it prints a warning, writes to the system log (`logger`, `auth.warning`) and exits with code 1.
4. **Schedule:** `cron` runs the check every Monday at 11:15.

## Usage

```bash
# 1. Install
sudo install -m 700 check_security.sh /usr/local/bin/check_security.sh

# 2. Create the baseline (once, on a trusted system)
sudo check_security.sh --init

# 3. Run a check manually
sudo check_security.sh

# 4. Schedule it every Monday at 11:15 (root crontab, because /etc/shadow is root-only)
sudo crontab -e
#   15 11 * * 1 /usr/local/bin/check_security.sh
```

Exit codes: `0` no change, `1` change detected, `2` error or missing baseline.

## Test cases

| Situation | Expected result |
|-----------|-----------------|
| Nothing changed | `No changes found.` (exit 0) |
| New system account created (for example `useradd -r testcron`) | Warning, the new user is shown in the diff (exit 1) |
| Password entry of a system user modified | Warning (exit 1) |
| Normal user (UID 1000 and above) modified | Ignored (exit 0) |

## What improved compared to the first version

The first version (the school exercise) worked as a demo but had limits that I identified afterwards:

- It used **relative paths**, which break when cron runs from another directory. The new version uses absolute paths.
- It ran `sudo` inside a scheduled task, which needs a password. The new version is meant to run from the **root crontab**.
- It copied `/etc/shadow` into `/tmp`, where password hashes could be read. The new version keeps only a **fingerprint** (SHA-256) in a protected directory (`umask 077`).
- It only printed a warning on screen. The new version also writes to the **system log** and returns an **exit code**.

## Possible next steps

- Send an e-mail alert (`MAILTO` in cron, or `mail`)
- Also watch `/etc/sudoers`, SSH `authorized_keys` and new listening ports
- Package it as a systemd timer instead of cron

## Tech

Linux, bash, awk, diff, sha256sum, cron, logger
