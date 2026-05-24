## Device & Architecture Context

QManager is a Next.js (static export) frontend + OpenWRT CGI shell backend, deployed **onto the modem itself** (Quectel RM520N/RM551E/RM500Q-class running OpenWRT). Backend = BusyBox `/bin/sh` scripts under `scripts/www/cgi-bin/`, daemons under `scripts/usr/bin/`, shared libs under `scripts/usr/lib/qmanager/`. Modem talks via `qcmd` AT-command wrapper. Because the app runs on the device, anything that reboots the modem also kills any in-flight HTTP request — defer reboots via dialog + persistent banner, never `AT+CFUN=1,1` mid-request.

See `docs/ARCHITECTURE.md`, `docs/BACKEND.md`, `docs/FRONTEND.md`, `docs/API-REFERENCE.md` for full breakdowns.

## Design Context

See **`PRODUCT.md`** (strategic: register, users, brand personality, anti-references, the six design principles including the safety principle, accessibility) and **`DESIGN.md`** (visual: OKLCH tokens, Manrope-only typography, status-badge pattern, hybrid elevation, mosaic dashboard composition, signature components — Topology Map / Circular Signal Meter / Live Data Tile, Apple-class motion contracts, full Do's and Don'ts).

Quick reminders the visual spec enforces:
- **Status badges**: always `variant="outline"` + `bg-{role}/15 text-{role} border-{role}/30` + `size-3` lucide icon. Solid variants are forbidden in feature surfaces. Reusable wrapper: `ServiceStatusBadge` at `components/local-network/service-status-badge.tsx`.
- **CardHeader**: plain `CardTitle` + `CardDescription`. No icons in headers; they go in badges or `CardAction`.
- **Save actions**: always use `SaveButton`.
- **Single typeface**: Manrope only. No Geist Mono, no second font. Live numeric readouts use `font-variant-numeric: tabular-nums`.
- **Dashboards**: varied-size mosaic (one hero widget + smaller tiles), never a uniform card grid.

## Probing the Live Modem (Development)

A live test modem is reachable on the LAN; **SSH credentials live in `.env`** (`SSH_HOST`, `SSH_USERNAME`, `SSH_PASSWORD`). When debugging backend behavior, reproducing CGI output, verifying a shell-script change actually runs under the device's BusyBox `/bin/sh`, or sanity-checking that a fix landed on disk, probe the device via PowerShell's **Posh-SSH** module rather than guessing from code alone.

One-time install (per dev machine):

```powershell
Install-Module Posh-SSH -Scope CurrentUser
```

Quick pattern (read variables from `.env`, do NOT hardcode or echo secrets in transcripts):

```powershell
$cred = [pscredential]::new($env:SSH_USERNAME, (ConvertTo-SecureString $env:SSH_PASSWORD -AsPlainText -Force))
$sess = New-SSHSession -ComputerName $env:SSH_HOST -Credential $cred -AcceptKey -Force
(Invoke-SSHCommand -SessionId $sess.SessionId -Command 'uci show qmanager').Output
Remove-SSHSession -SessionId $sess.SessionId | Out-Null
```

Use it to: read live UCI config, inspect `/tmp/qmanager_*.json` runtime state, tail `/tmp/qmanager.log` and other logs, hit a CGI endpoint with `curl http://127.0.0.1/cgi-bin/quecmanager/...`, check lock files (`/var/run/qmanager_*.pid`, `/tmp/qmanager_*.lock`), exercise `qcmd` AT calls, confirm `nft list ruleset` after a DPI toggle, verify init.d state, and re-read written config after an apply.

**Safety:**
- Treat the modem as a live system. Avoid destructive commands (reboots, `AT+CFUN=1,1`, factory resets, package removals, `rm -rf`) without a stated reason.
- Never echo `.env` values back to the user or paste them into transcripts; reference the variable names instead.
- `.env` should remain gitignored. Verify with `git check-ignore .env` before committing anything in the repo root.

## Release Notes (`RELEASE_NOTE.md`)

Sections: `## ✨ New Features`, `## ✅ Improvements`, `## 📥 Installation`, `## 💙 Thank You`. Short user-facing bullets; no internal function names. Headline features first; fixes/polish under Improvements. Include the one-line fresh install command + Software Update upgrade path.

## Shared Constants
- **`ANTENNA_PORTS`** (`types/modem-status.ts`): canonical metadata for 4 ports (Main/PRX, Diversity/DRX, MIMO 3/RX2, MIMO 4/RX3). Used by `antenna-statistics` + `antenna-alignment`. Do not duplicate.

## Feature Docs — Read On Demand

Detailed per-feature notes (apply pipelines, lock layering, contracts, gotchas, error codes) have been extracted to `docs/features/`. **Before editing any of these features, read the matching doc first** — they contain non-obvious invariants that aren't visible from the code alone.

| If you're touching… | Read |
|---|---|
| Video Optimizer, Traffic Masquerade, `nfqws`, NFQUEUE 200, `/etc/nftables.d/12-mangle-qmanager-dpi.nft` | [`docs/features/dpi-settings.md`](docs/features/dpi-settings.md) |
| Custom SIM Profiles, `qmanager_profile_apply`, `profile_mgr.sh`, Verizon MPDN, ICCID auto-apply, profile lock files | [`docs/features/custom-sim-profiles.md`](docs/features/custom-sim-profiles.md) |
| Config Backup / Restore, `.qmbackup`, `qmanager_config_restore`, `config_backup_sections.sh`, deferred-reboot banner | [`docs/features/config-backup-restore.md`](docs/features/config-backup-restore.md) |
| Language packs, i18n loading, `qmanager_language_install`, `language_packs.sh`, manifest, `bun run package:lang` | [`docs/features/language-packs.md`](docs/features/language-packs.md) |
| Backend error envelopes, `resolveErrorMessage`, `errors.json`, `at-commands` namespace | [`docs/features/error-codes.md`](docs/features/error-codes.md) |
| Tower locking, `qmanager_tower_failover`, signal failover daemon, failover spawn gating | [`docs/features/tower-lock-failover.md`](docs/features/tower-lock-failover.md) |
| `/cellular/antenna-alignment`, alignment meter, antenna type toggle | [`docs/features/antenna-alignment.md`](docs/features/antenna-alignment.md) |

Quick CGI / hook / type / reboot table for all extracted features lives in [`docs/features/README.md`](docs/features/README.md).

If you add a substantial new feature with non-obvious invariants, drop its notes into `docs/features/<feature>.md` and add a row above rather than re-fattening this file.
