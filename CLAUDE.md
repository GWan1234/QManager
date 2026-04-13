## Design Context

### Users
- **Hobbyist power users** optimizing home cellular setups for better speeds, band locking, and coverage
- **Field technicians** deploying and maintaining Quectel modems on OpenWRT devices
- Context: users are technically literate but not necessarily developers. They want clear, actionable information without needing to memorize AT commands. Sessions range from quick checks (signal status) to focused configuration (APN, band locking, profiles).

### Brand Personality
**Modern, Approachable, Smart** — a friendly expert. Not intimidating or overly technical in presentation, but deeply capable underneath. The interface should feel like a premium tool that respects the user's intelligence without requiring them to be a modem engineer.

### Aesthetic Direction
- **Visual tone:** Clean and modern with purposeful density where data matters. Polish of Vercel/Linear meets the functional depth of Grafana/UniFi.
- **References:** Apple System Preferences (clarity, hierarchy), Vercel/Linear (typography, motion, whitespace), Grafana/Datadog (data visualization density), UniFi (network management UX patterns)
- **Anti-references:** Avoid raw terminal aesthetics, cluttered legacy network tools, or overly playful/consumer app styling. Never sacrificial clarity for visual flair.
- **Theme:** Light and dark mode, both first-class. OKLCH color system already in place.
- **Typography:** Euclid Circular B (primary), Manrope (secondary). Clean, geometric, professional.
- **Radius:** 0.65rem base — softly rounded, not pill-shaped.

### Status Badge Pattern
All status badges use `variant="outline"` with semantic color classes and `size-3` lucide icons. Never use solid badge variants (`variant="success"`, `variant="destructive"`, etc.) for status indicators.

| State | Classes | Icon |
| ----- | ------- | ---- |
| Success/Active | `bg-success/15 text-success hover:bg-success/20 border-success/30` | `CheckCircle2Icon` |
| Warning | `bg-warning/15 text-warning hover:bg-warning/20 border-warning/30` | `TriangleAlertIcon` |
| Destructive/Error | `bg-destructive/15 text-destructive hover:bg-destructive/20 border-destructive/30` | `XCircleIcon` or `AlertCircleIcon` |
| Info | `bg-info/15 text-info hover:bg-info/20 border-info/30` | Context-specific (`DownloadIcon`, `ClockIcon`, etc.) |
| Muted/Disabled | `bg-muted/50 text-muted-foreground border-muted-foreground/30` | `MinusCircleIcon` |

```tsx
<Badge variant="outline" className="bg-success/15 text-success hover:bg-success/20 border-success/30">
  <CheckCircle2Icon className="size-3" />
  Active
</Badge>
```

- Reusable `ServiceStatusBadge` component at `components/local-network/service-status-badge.tsx` for service running/inactive states
- Choose muted for deliberately inactive states (Stopped, Offline peer, Disabled); destructive for failure/error states (Disconnected link, Failed email)

### Design Principles

1. **Data clarity first** — Signal metrics, latency charts, and network status are the core experience. Every pixel should serve readability and quick comprehension. Use color, spacing, and hierarchy to make numbers scannable at a glance.
2. **Progressive disclosure** — Show the essential information upfront; advanced controls and details are accessible but not overwhelming. A quick-check user and a deep-configuration user should both feel served.
3. **Confidence through feedback** — Every action (save, reboot, apply profile) must have clear visual feedback: loading states, success confirmations, error messages. Users are changing real device settings — they need to trust what happened.
4. **Consistent, systematic** — Use the established shadcn/ui components and design tokens uniformly. No one-off styles. Cards, forms, tables, and dialogs should feel like they belong to one coherent system.
5. **Responsive and resilient** — Works on desktop monitors and tablets in the field. Degrade gracefully. Handle loading, empty, and error states intentionally — never show a blank screen.

### UI Component Conventions

- **CardHeader**: Always plain `CardTitle` + `CardDescription` without icons. Icons belong in badges or separate action areas, not in the card header itself.
- **Primary action buttons**: Use default variant (not outline) for main actions like Record, Save, Apply. Use `SaveButton` component for save-specific actions with loading animation.
- **Step-based progress**: Use `Loader2Icon` spinner + dot indicators for step/sample progress. Reserve fill/progress bars for data visualization (signal strength, quality meters) only.

## CGI Endpoint Reference (Additions)

| Feature      | CGI Script                   | Hook                                                   | Types                | Reboot? |
|--------------|------------------------------|--------------------------------------------------------|----------------------|---------|
| Video Optimizer | `network/video_optimizer.sh` | `use-video-optimizer.ts` + `use-cdn-hostlist.ts` | `video-optimizer.ts` | No |
| Traffic Masquerade | `network/video_optimizer.sh` | `use-traffic-masquerade.ts` | `video-optimizer.ts` | No |
| NetBird VPN | `vpn/netbird.sh` | `use-netbird.ts` | In hook file | Yes (uninstall) |
| Configuration Backup | `system/config-backup/{collect,apply,apply_status,apply_cancel}.sh` | `use-config-backup.ts` + `use-config-restore.ts` | `config-backup.ts` | Sometimes (deferred — IMEI / profile activation queues a user-initiated reboot via dialog + persistent banner) |

## Feature-Specific Notes

### DPI Settings (Video Optimizer + Traffic Masquerade)

- **Two separate pages**: `/local-network/video-optimizer` (2-card grid: settings + CDN hostlist) and `/local-network/traffic-masquerade` (single card)
- **Old route** `/local-network/dpi-masking` redirects to video-optimizer
- **Binary**: nfqws from zapret project, installed at `/usr/bin/nfqws`
- **Not bundled**: nfqws is downloaded on demand from [zapret GitHub releases](https://github.com/bol-van/zapret/releases) via `qmanager_dpi_install` — avoids opkg dependency issues on custom firmware
- **Installer**: `qmanager_dpi_install` — detects arch, fetches `openwrt-embedded.tar.gz`, extracts arch-specific binary, installs to `/usr/bin/nfqws`
- **Installer state**: `/tmp/qmanager_dpi_install.json` (progress file), `/tmp/qmanager_dpi_install.pid` (singleton guard)
- **Hostname list**: `/etc/qmanager/video_domains.txt` (user-editable, curated video CDNs)
- **Default hostname list**: `/etc/qmanager/video_domains_default.txt` (immutable factory default for restore)
- **Hostlist CGI**: GET `?section=hostlist` returns domains array; POST `save_hostlist` (full replace + atomic write); POST `restore_hostlist` (copy default over active)
- **Single shared nfqws instance**: VO and masquerade are mutually exclusive modes of ONE nfqws process on queue 200 — single PID file (`/var/run/nfqws.pid`), single set of nftables rules (comment `qmanager_dpi`), single packet counter
- **Mutual exclusion**: Backend enforces in `save`/`save_masquerade` — enabling one disables the other in UCI. Init.d `start_service()` checks masquerade first, then VO (if/elif)
- **Video Optimizer mode**: NFQUEUE queue 200, `bypass` flag; TCP SNI split (`--dpi-desync=split2`) + QUIC desync (`--dpi-desync-udplen-increment`), filtered by `--hostlist`
- **Traffic Masquerade mode**: same queue 200; fake TLS ClientHello with spoofed SNI (default: `speedtest.net`) using `--dpi-desync=fake --dpi-desync-fake-tls-mod=sni=<domain> --dpi-desync-fooling=badseq`, applies to all traffic (no hostlist)
- **Status isolation**: CGI GET handlers gate live stats (status/uptime/packets) on UCI `enabled` flag — prevents cross-contamination since both modes share the same process/counters
- **Verification**: `qmanager_dpi_verify` — curl with `--connect-to` SNI spoofing against speed.cloudflare.com
- **Kernel support**: `dpi_check_kmod()` checks `/proc/config.gz` for `CONFIG_NETFILTER_NETLINK_QUEUE=y` (built-in) before trying lsmod/modprobe
- **Init.d**: `qmanager_dpi` (procd, START=99, UCI-gated, single nfqws instance in either VO or masquerade mode)
- **Boot persistence**: CGI `save`/`save_masquerade` calls `enable`/`disable` on init.d. Enabling either feature → `enable` (survives boot). Disabling → `disable` only if the other feature is also off. Uninstall always `disable`s.
- **Installer jq caveat**: OpenWRT's jq lacks oniguruma — `test()` silently fails. Use `endswith()`/`contains()` instead (see memory: jq-no-regex)
- **Dependencies**: `libnetfilter-queue`, `libnfnetlink`, `libmnl`, full `curl` (not BusyBox); kernel NFQUEUE support (built-in or `kmod-nft-queue`)

### Custom SIM Profiles

- **Route**: `/cellular/custom-profiles`
- **IMEI is optional** — empty string = don't change. Profile can be created without an IMEI.
- **Apply is async**: `profiles/apply.sh` spawns `qmanager_profile_apply` detached, frontend polls `profiles/apply_status.sh` at 500ms
- **3 steps**: APN → TTL/HL → IMEI (least → most disruptive). Each step has skip logic (unchanged = skipped).
- **Active marker**: `/etc/qmanager/active_profile` (plain text file with profile ID). Set on complete/partial apply, cleared on deactivate/delete/total-failure.
- **IMEI pre-set**: Active marker is written BEFORE `AT+CFUN=1,1` (modem reboot can trigger system reboot on some USB configs, killing the script before finalization). Finalization re-sets on success/partial, clears on total failure.
- **Activate ≠ Toggle**: "Activate" runs the full 3-step apply pipeline. "Deactivate" only clears the active marker — zero modem changes.
- **SIM mismatch auto-deactivation**: Poller `collect_boot_data()` checks active profile's `sim_iccid` against current SIM at boot. If mismatch → auto-clears active marker + emits `profile_deactivated` warning event. Profiles with empty `sim_iccid` are left alone (not SIM-bound).
- **SIM mismatch UI**: `custom-profile-table.tsx` compares active profile's `sim_iccid` against `modemStatus.device.iccid`. Mismatch → warning badge ("SIM Mismatch" with `TriangleAlertIcon`) instead of blue "Active" badge.
- **Profile events**: `profile_applied` (info/warning), `profile_failed` (error), `profile_deactivated` (info/warning) — emitted by `qmanager_profile_apply` and `deactivate.sh`, displayed in Network Events (dataConnection tab)
- **TTL override**: `ttl-settings-card.tsx` disables form when active profile has TTL/HL > 0
- **ICCID auto-apply (2026-04-10)**: `profile_mgr.sh::auto_apply_profile <iccid> <caller>` looks up a profile by current SIM ICCID and spawns `qmanager_profile_apply` detached. Triggered from 4 call sites, all using the subshell-sourcing pattern `( . /usr/lib/qmanager/profile_mgr.sh && auto_apply_profile "$iccid" "<tag>" )` to avoid polluting the caller's environment:
  - `qmanager_poller::collect_boot_data()` — tag `boot`, reuses `$boot_iccid` captured earlier
  - `cellular/settings.sh` after successful SIM slot change — tag `sim_switch`, 3×1s ICCID retry for slow SIM registration
  - `qmanager_watchcat::finish_cooldown()` Tier 3 success — tag `watchdog`, reuses `$curr_iccid`
  - `qmanager_watchcat::sim_failover_fallback()` after `wait_for_modem` — tag `watchdog_revert`, 3×1s ICCID retry
- **Auto-apply safety**: `auto_apply_profile` guards on `profile_check_lock` (won't race a manual Activate click) and `profile_count > 0` (no log noise on fresh installs). The apply worker's per-step skip logic (APN/TTL/IMEI) is the single source of truth for "only apply what differs" — `auto_apply_profile` does NOT pre-compare settings, it just spawns the worker.

### Configuration Backup and Restore

- **Route**: `/system-settings/config-backup`
- **8 sections, mutually-exclusive overlap rule**: Network Mode + APN, LTE/5G bands, Tower Lock, TTL/HL, IMEI, Custom SIM Profiles, SMS Alerts, Watchdog. Checking "Custom SIM Profiles" force-disables APN, TTL/HL, IMEI (and vice versa) — they're the same settings that profile activation owns
- **Encryption**: Mandatory passphrase, AES-256-GCM via WebCrypto in the browser. PBKDF2-SHA256 200k iterations, 16-byte random salt, 12-byte random IV per backup. Header (`magic`, `version`, `created_at`, `device`, `sections_included`) is bound as AES-GCM Associated Data via `canonicalHeaderAad()` so tampering with the visible header invalidates the file. Passphrase never leaves the browser
- **File format**: `.qmbackup` envelope is a JSON document — header in plaintext, ciphertext base64-encoded with the 16-byte GCM tag appended. Filename pattern: `qmanager-<model>-<YYYYMMDD-HHMMSS>.qmbackup` (UTC timestamp to match `created_at`)
- **Section library**: `/usr/lib/qmanager/config_backup_sections.sh` exposes a pair of `collect_<key>` / `apply_<key>` functions per section + a `cfg_backup_collect`/`cfg_backup_apply` dispatcher. New section = add one pair + register the case statement entries. Library is sourced by both `collect.sh` (CGI) and the worker — caller owns `qlog_init` (the library does NOT call it, see Task 5 review)
- **Apply order on restore (canonical, fixed)**: `sms_alerts → watchdog → network_mode_apn → bands → tower_lock → ttl_hl → imei → profiles`. Safe sections first, IMEI/profiles last (the only sections that queue reboots)
- **Async apply worker**: `/usr/bin/qmanager_config_restore` modeled after `qmanager_profile_apply`. Detached double-fork via `apply.sh`, PID file at `/var/run/qmanager_config_restore.pid`, progress JSON at `/tmp/qmanager_config_restore.json`, input at `/tmp/qmanager_config_restore_input.json`, cancel sentinel at `/tmp/qmanager_config_restore.cancel`
- **Retry policy**: 3 retries per section (4 attempts total) with exponential backoff 1s/2s/4s. Retry only on generic failure (rc=1). Exit codes 2 (unsupported, skip) and 3 (profiles SIM mismatch) bypass retries. Cancellation is checked between sections — cannot abort mid-AT-command
- **Per-section result states**: `pending`, `running`, `retrying:N`, `success`, `failed`, `skipped:incompatible`, `skipped:not_in_backup`, `skipped:sim_mismatch`. The frontend's `RestoreProgressList` uses a shared `min-w-[7.5rem] justify-center` base on every status badge so widths stay identical across status transitions
- **Deferred reboot pattern (CRITICAL — QManager runs ON the modem)**: Both `apply_imei` and `apply_profiles` deliberately do NOT trigger reboots. `apply_imei` writes IMEI to NVM via `AT+EGMR=1,7,"<imei>"` but does NOT call `AT+CFUN=1,1`. `apply_profiles` writes `/etc/qmanager/active_profile` but does NOT spawn `qmanager_profile_apply`. Both `touch /tmp/qmanager_config_restore.reboot_required` as a hint. The worker reads this hint in `state_write` and surfaces `reboot_required: true` in the progress JSON. The frontend pops a `Reboot Now` / `Reboot Later` AlertDialog after restore success, plus a persistent `Alert` banner on the page (localStorage-backed at `qmanager_pending_reboot`) that survives navigation/reload. **One reboot total** — on the next user-initiated reboot, the boot-time `auto_apply_profile` in the poller picks up the active marker and runs the profile pipeline, finding the IMEI already correct (no second reboot)
- **Reboot dialog non-OK handling**: Both `handleRebootNow` handlers (in `restore-backup-card.tsx` and `config-backup.tsx`) check `res.ok` after the `system/reboot.sh` POST and rethrow on non-2xx. `authFetch` only throws on network errors, so a 500 from the reboot CGI would otherwise leave the user stranded with the pending flag cleared and the dialog stuck in "Rebooting…"
- **Concurrency guard**: `apply.sh` returns 409 if the worker PID file exists and the PID is alive. Both `apply.sh` and `apply_cancel.sh` reject non-POST requests (a stray authenticated GET to cancel could otherwise silently abort a running restore)
- **Body size cap**: 256 KiB on `apply.sh` enforced via `CONTENT_LENGTH` inspection before reading stdin
- **Cross-device validation**: Backup records `device.model` / `firmware` / `imei`. The browser compares `device.model` against `useModemStatus().data?.device.model` and transitions to a `model_warning` UI state on mismatch. Per-section appliers silently downgrade unsupported items to `skipped:incompatible` regardless of the warning
- **Active profile auto-activation**: ICCID match check (`profile_iccid` vs `current_iccid` from `/tmp/qmanager_status.json`) — mismatch returns rc=3 → worker maps to `skipped:sim_mismatch` and the active marker is NOT written
- **Network events**: 6 new event types in the `dataConnection` tab — `config_backup_collected`, `config_restore_started`, `config_restore_section_success`, `config_restore_section_failed`, `config_restore_section_skipped`, `config_restore_completed`. All emitted by the worker except `config_backup_collected` which is emitted by `collect.sh` on successful return
- **Pure-TS modules under test**: `lib/config-backup/{crypto,format,sections}.ts` have `*.test.ts` files run via `bun test`. This is the project's first Bun test setup — `tsconfig.json` excludes `**/*.test.ts` so `bun tsc --noEmit` doesn't choke on `bun:test` imports without DOM lib types
- **TS 5.9 BufferSource quirk**: `crypto.ts` accepts bare `Uint8Array` in its public API (callers passing `subarray()`/`slice()` results would otherwise hit the tightened `Uint8Array<ArrayBufferLike>` constraint). Internal coercion via a private `toFixedBuffer()` helper produces the `Uint8Array<ArrayBuffer>` that `crypto.subtle.*` actually requires

### Antenna Alignment

- **Route**: `/cellular/antenna-alignment`
- **No CGI endpoint** — reads exclusively from `useModemStatus` hook (poller cache `signal_per_antenna` field)
- **Component structure**: Coordinator pattern — `antenna-alignment.tsx` (coordinator) + `antenna-card.tsx` (per-port detail) + `alignment-meter.tsx` (3-position recording tool) + `utils.ts` (shared helpers/constants)
- **Shared constant**: Uses `ANTENNA_PORTS` from `types/modem-status.ts` (re-exported via local `utils.ts`)
- **Signal quality gotcha**: `getSignalQuality()` returns **lowercase** strings (`"excellent"`, `"good"`, `"fair"`, `"poor"`, `"none"`). All `switch`/map consumers MUST use lowercase keys.
- **Alignment Meter**: 3-slot recording tool that averages `SAMPLES_PER_RECORDING` (3) samples per slot. Compares composite RSRP+SINR scores (60/40 weight) to recommend best antenna position or angle.
- **Two antenna types**: Directional (angles: 0/45/90) and Omni (positions: A/B/C) — user-selectable via toggle group, labels are editable
- **Recording progress**: Uses `Loader2Icon` spinner + step dots (NOT fill bars — those are reserved for signal quality visualization per UI Component Conventions)
- **Radio mode detection**: `detectRadioMode()` inspects all 4 antennas for valid LTE/NR data and returns `"lte"`, `"nr"`, or `"endc"`
- **Best recommendation**: Appears after 2+ slots recorded; composite score = 60% RSRP + 40% SINR (primary antenna, NR preferred over LTE in EN-DC mode)

## Shared Constants

- **`ANTENNA_PORTS`** (`types/modem-status.ts`): Canonical metadata for 4 antenna ports (Main/PRX, Diversity/DRX, MIMO 3/RX2, MIMO 4/RX3). Used by `antenna-statistics` and `antenna-alignment`. Any new per-antenna UI must import from here — do not duplicate port definitions.
