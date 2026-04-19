## Design Context

**Users**: hobbyist power users + field technicians managing Quectel modems on OpenWRT. Technically literate, not developers. Sessions range from quick checks to focused configuration.

**Brand**: Modern, Approachable, Smart — premium tool that respects user intelligence without requiring modem-engineer knowledge.

**Aesthetic**: Vercel/Linear polish meets Grafana/UniFi density. Light + dark first-class (OKLCH). Euclid Circular B (primary), Manrope (secondary). Radius `0.65rem`. Avoid terminal/legacy/consumer styling.

### Status Badge Pattern
All status badges: `variant="outline"` + semantic color classes + `size-3` lucide icons. Never solid variants.

| State | Classes | Icon |
| ----- | ------- | ---- |
| Success | `bg-success/15 text-success hover:bg-success/20 border-success/30` | `CheckCircle2Icon` |
| Warning | `bg-warning/15 text-warning hover:bg-warning/20 border-warning/30` | `TriangleAlertIcon` |
| Destructive | `bg-destructive/15 text-destructive hover:bg-destructive/20 border-destructive/30` | `XCircleIcon` / `AlertCircleIcon` |
| Info | `bg-info/15 text-info hover:bg-info/20 border-info/30` | Context-specific |
| Muted | `bg-muted/50 text-muted-foreground border-muted-foreground/30` | `MinusCircleIcon` |

Reusable `ServiceStatusBadge` at `components/local-network/service-status-badge.tsx`. Use muted for deliberately inactive states; destructive for failure/error states.

### Design Principles
1. **Data clarity first** — metrics scannable at a glance.
2. **Progressive disclosure** — essentials upfront, advanced controls accessible.
3. **Confidence through feedback** — every action shows loading/success/error.
4. **Consistent** — shadcn/ui + design tokens uniformly, no one-off styles.
5. **Responsive + resilient** — graceful loading/empty/error states, never blank.

### UI Component Conventions
- **CardHeader**: plain `CardTitle` + `CardDescription`, no icons (icons go in badges / action areas).
- **Primary actions**: default variant (not outline). Use `SaveButton` for save actions.
- **Step progress**: `Loader2Icon` spinner + dot indicators. Reserve fill bars for data viz (signal strength, quality meters) only.

## Release Notes (`RELEASE_NOTE.md`)

Sections: `## ✨ New Features`, `## ✅ Improvements`, `## 📥 Installation`, `## 💙 Thank You`. Short user-facing bullets; no internal function names. Headline features first; fixes/polish under Improvements. Include the one-line fresh install command + Software Update upgrade path.

## CGI Endpoint Reference (Additions)

| Feature | CGI Script | Hook | Types | Reboot? |
|---|---|---|---|---|
| Video Optimizer | `network/video_optimizer.sh` | `use-video-optimizer.ts` + `use-cdn-hostlist.ts` | `video-optimizer.ts` | No |
| Traffic Masquerade | `network/video_optimizer.sh` | `use-traffic-masquerade.ts` | `video-optimizer.ts` | No |
| NetBird VPN | `vpn/netbird.sh` | `use-netbird.ts` | inline | Yes (uninstall) |
| Config Backup | `system/config-backup/{collect,apply,apply_status,apply_cancel}.sh` | `use-config-backup.ts` + `use-config-restore.ts` | `config-backup.ts` | Deferred (dialog + banner for IMEI/profile) |

## Feature-Specific Notes

### DPI Settings (Video Optimizer + Traffic Masquerade)
- Routes: `/local-network/video-optimizer` (settings + CDN hostlist), `/local-network/traffic-masquerade`. Old `/local-network/dpi-masking` redirects.
- Binary: `nfqws` from zapret, installed to `/usr/bin/nfqws` on demand by `qmanager_dpi_install` (arch-detect → fetch `openwrt-embedded.tar.gz`). State files: `/tmp/qmanager_dpi_install.{json,pid}`.
- **Single shared nfqws on queue 200** — VO and masquerade are mutually exclusive modes of ONE process: single PID (`/var/run/nfqws.pid`), single nft rule set (comment `qmanager_dpi`). Backend enforces mutex in `save`/`save_masquerade`; init.d checks masquerade first, then VO.
- Modes: VO = SNI split (`split2`) + QUIC desync, filtered by `--hostlist`. Masquerade = fake TLS ClientHello with spoofed SNI (default `speedtest.net`), all traffic.
- Hostlist: `/etc/qmanager/video_domains.txt` (active) + `video_domains_default.txt` (immutable). Hostlist CGI supports GET `?section=hostlist`, POST `save_hostlist`, POST `restore_hostlist`.
- GET handlers gate live stats on UCI `enabled` to avoid cross-mode contamination. Kernel check: `dpi_check_kmod()` reads `/proc/config.gz` for `CONFIG_NETFILTER_NETLINK_QUEUE=y`.
- Boot persistence: enabling either mode → init.d `enable`; disabling → `disable` only if BOTH are off. Uninstall always `disable`s.
- Deps: `libnetfilter-queue`, `libnfnetlink`, `libmnl`, full `curl`, NFQUEUE kernel support.

### Custom SIM Profiles
- Route: `/cellular/custom-profiles`. IMEI is optional (empty = don't change).
- **Async 3-step apply** (APN → TTL/HL → IMEI, least → most disruptive). Each step skips when unchanged. Worker: `qmanager_profile_apply`, polled via `profiles/apply_status.sh` at 500ms.
- Active marker: `/etc/qmanager/active_profile` (plain text, profile ID). Written BEFORE `AT+CFUN=1,1` (USB reset can kill the script). Finalization re-writes on success/partial; clears on total failure.
- Activate = runs full pipeline. Deactivate = clears marker only, zero modem changes.
- **SIM mismatch**: poller `collect_boot_data()` auto-clears marker + emits `profile_deactivated` when active profile's `sim_iccid` ≠ current SIM. Empty `sim_iccid` = SIM-agnostic, left alone. Frontend shows "SIM Mismatch" warning badge.
- TTL override: `ttl-settings-card.tsx` disables form when active profile has TTL/HL > 0.
- **ICCID auto-apply**: `profile_mgr.sh::auto_apply_profile <iccid> <caller>` spawns worker detached. Called via `( . /usr/lib/qmanager/profile_mgr.sh && auto_apply_profile "$iccid" "<tag>" )` from: poller boot (`boot`), `cellular/settings.sh` post-SIM-switch (`sim_switch`, 3×1s ICCID retry), watchcat Tier 3 success (`watchdog`), watchcat SIM failover fallback (`watchdog_revert`, 3×1s retry).
- Auto-apply guards: `profile_check_lock` (no race with manual Activate) + `profile_count > 0`. Worker's per-step skip logic is the single source of truth for "only apply what differs" — `auto_apply_profile` does NOT pre-compare.
- Events: `profile_applied`/`profile_failed`/`profile_deactivated` in `dataConnection` tab.

### Configuration Backup and Restore
- Route: `/system-settings/config-backup`. 8 sections: Network Mode + APN, LTE/5G bands, Tower Lock, TTL/HL, IMEI, Custom SIM Profiles, SMS Alerts, Watchdog.
- **Overlap rule**: Custom SIM Profiles is mutex with APN/TTL/HL/IMEI — profile activation owns those.
- **Encryption**: mandatory passphrase, AES-256-GCM via WebCrypto. PBKDF2-SHA256 200k iters, 16-byte salt, 12-byte IV. Header bound as AES-GCM AAD via `canonicalHeaderAad()`. Passphrase never leaves browser.
- **File**: `.qmbackup` JSON envelope — plaintext header + base64 ciphertext (+ appended GCM tag). Filename: `qmanager-<model>-<YYYYMMDD-HHMMSS>.qmbackup` (UTC).
- **Section library**: `/usr/lib/qmanager/config_backup_sections.sh` — one `collect_<key>`/`apply_<key>` pair per section + `cfg_backup_{collect,apply}` dispatcher. Sourced by `collect.sh` CGI + worker. **Caller owns `qlog_init`**.
- **Apply order (fixed)**: `sms_alerts → watchdog → network_mode_apn → bands → tower_lock → ttl_hl → imei → profiles`. Safe first, reboot-queuing last.
- **Async worker**: `/usr/bin/qmanager_config_restore` (double-fork via `apply.sh`). PID `/var/run/qmanager_config_restore.pid`; progress `/tmp/qmanager_config_restore.json`; input `/tmp/qmanager_config_restore_input.json`; cancel `/tmp/qmanager_config_restore.cancel`.
- **Retry**: 3 retries, backoff 1s/2s/4s, only on rc=1. rc=2 (unsupported) / rc=3 (SIM mismatch) bypass retries. Cancel checked between sections.
- **States**: `pending`, `running`, `retrying:N`, `success`, `failed`, `skipped:incompatible`, `skipped:not_in_backup`, `skipped:sim_mismatch`. Frontend `RestoreProgressList` uses `min-w-[7.5rem] justify-center` on all badges for width stability.
- **Deferred reboot (CRITICAL — QManager runs ON the modem)**: `apply_imei` writes IMEI via `AT+EGMR=1,7,"<imei>"` but does NOT `AT+CFUN=1,1`. `apply_profiles` writes `active_profile` marker but does NOT spawn `qmanager_profile_apply`. Both `touch /tmp/qmanager_config_restore.reboot_required`. Worker surfaces `reboot_required: true`. Frontend shows reboot AlertDialog + persistent banner (localStorage `qmanager_pending_reboot`). **One reboot total** — on next reboot, poller's boot-time `auto_apply_profile` picks up the marker, finds IMEI already correct.
- Reboot dialog handlers in `restore-backup-card.tsx` / `config-backup.tsx` check `res.ok` and rethrow on non-2xx (`authFetch` only throws on network errors).
- Guards: `apply.sh` returns 409 on active PID. `apply.sh`/`apply_cancel.sh` reject non-POST. 256 KiB cap via `CONTENT_LENGTH`.
- Cross-device: backup records `device.{model,firmware,imei}`. Browser compares `device.model` → `model_warning` state on mismatch. Appliers still silently downgrade unsupported items to `skipped:incompatible`.
- Profile auto-activation: ICCID match (`profile_iccid` vs `/tmp/qmanager_status.json::current_iccid`); mismatch → rc=3 → `skipped:sim_mismatch`, marker NOT written.
- Events (`dataConnection` tab): `config_backup_collected`, `config_restore_{started,section_success,section_failed,section_skipped,completed}`.
- Tests: `lib/config-backup/{crypto,format,sections}.test.ts` via `bun test`. Project's first Bun test setup — `tsconfig.json` excludes `**/*.test.ts` so `bun tsc --noEmit` doesn't choke on `bun:test` imports.
- TS 5.9 quirk: `crypto.ts` public API accepts bare `Uint8Array`; private `toFixedBuffer()` coerces to `Uint8Array<ArrayBuffer>` for `crypto.subtle.*`.

### Tower Lock Failover (v0.1.18+)
- Route: `/cellular/tower-locking`.
- **Contract**: LTE/NR-SA cell lock does NOT auto-enable Signal Failover — user must explicitly flip switch in `tower-settings.tsx`. Unlocking still auto-stops + auto-disables failover.
- Default: `TOWER_DEFAULT_CONFIG.failover.enabled = false`. Existing configs preserved by `tower_config_init` on upgrade.
- Install gating: `qmanager_tower_failover` in `UCI_GATED_SERVICES` (install.sh) — fresh install cannot auto-run; upgrade preserves prior symlink.
- **Unlock hardening**: init.d `stop` = SIGTERM → poll `is_daemon_pid_running` up to 2s via `sleep_fractional` (`usleep 100000` fallback to `sleep 1`) → `kill -9`. Always clears `$PID_FILE` + `$ACTIVATED_FLAG`, `return 0`.
- **Self-heal**: `failover_status.sh` (polled 3s) checks `.lte.enabled`/`.nr_sa.enabled`. Orphan watcher with no active lock → inline `stop` (NOT `disable` — preserve user's `failover.enabled` intent).
- **Spawn gating**: `tower_spawn_failover_watcher()` is the single choke point — early-returns `"false"` when `.failover.enabled != "true"`. All callers (`lock.sh`, `settings.sh`, `qmanager_tower_schedule`) go through it.
- Frontend: `use-tower-locking.ts::sendLockRequest` does NOT force `config.failover.enabled = true` from `data.failover_armed`. Config flows only from `fetchStatus()` / `updateSettings()`.
- UX hint: `tower-settings.tsx` shows "Failover is off — enable it to auto-unlock on poor signal." when `hasActiveLock && !failover.enabled`.
- `settings.sh` disable-on-off + unlock-when-no-locks paths still run init.d `disable` (user intent). Band failover (`bands/lock.sh`) is out of scope — separate feature.

### Antenna Alignment
- Route: `/cellular/antenna-alignment`. No CGI — reads `useModemStatus` (`signal_per_antenna`).
- Structure: `antenna-alignment.tsx` (coordinator) + `antenna-card.tsx` + `alignment-meter.tsx` + `utils.ts`.
- Shared constant: `ANTENNA_PORTS` from `types/modem-status.ts` (re-exported via local `utils.ts`).
- **Signal quality gotcha**: `getSignalQuality()` returns **lowercase** (`excellent`/`good`/`fair`/`poor`/`none`). All switch/map consumers must use lowercase.
- Alignment Meter: 3-slot recorder, averages 3 samples per slot. Composite score = 60% RSRP + 40% SINR (primary antenna, NR preferred in EN-DC). Recommendation appears after 2+ slots.
- Two antenna types (user-selectable toggle): Directional (0°/45°/90°) + Omni (A/B/C), labels editable.
- Recording progress uses `Loader2Icon` + dots (not fill bars). `detectRadioMode()` returns `lte`/`nr`/`endc`.

## Shared Constants
- **`ANTENNA_PORTS`** (`types/modem-status.ts`): canonical metadata for 4 ports (Main/PRX, Diversity/DRX, MIMO 3/RX2, MIMO 4/RX3). Used by `antenna-statistics` + `antenna-alignment`. Do not duplicate.
