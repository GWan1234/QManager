# QManager Task Tracker

**Last Updated:** February 18, 2026

This file tracks component wiring progress, active work, and remaining tasks.  
For architecture, AT command reference, JSON contract, and deployment notes, see `DEVELOPMENT_LOG.md`.

---

## Page Wiring Progress

### Home Page Dashboard (`/dashboard`) — ✅ COMPLETE

All 10 home page components are wired to live data and functional.

| Component | File | Status | Data Source |
|-----------|------|--------|-------------|
| **Network Status** | `network-status.tsx` | ✅ Done | `data.network` + `data.modem_reachable` — network type icon, carrier, SIM slot, service status with pulsating rings, radio badge, loading skeletons, stale indicator |
| **4G Primary Status** | `lte-status.tsx` | ✅ Done | `data.lte` — band, EARFCN, PCI, RSRP, RSRQ, RSSI, SINR |
| **5G Primary Status** | `nr-status.tsx` | ✅ Done | `data.nr` — band, ARFCN, PCI, RSRP, RSRQ, SINR, SCS |
| **Device Information** | `device-status.tsx` | ✅ Done | `data.device` — firmware, build date, manufacturer, IMEI, IMSI, ICCID, phone, LTE category, MIMO |
| **Device Metrics** | `device-metrics.tsx` | ✅ Done | `data.device` (temp, CPU, memory, uptime) + `data.traffic` (live traffic, data usage) + `data.lte`/`data.nr` (TA cell distance) |
| **Internet Badge** | `network-status.tsx` | ✅ Done | `data.connectivity.internet_available` — three-state badge (green/red/gray) |
| **Live Latency** | `live-latency.tsx` | ✅ Done | `data.connectivity` — line chart, stats row, Online/Offline badge, speedtest button |
| **Recent Activities** | `recent-activities.tsx` | ✅ Done | Self-contained: `useRecentActivities()` hook, polls events CGI every 10s |
| **Signal History** | `signal-history.tsx` | ✅ Done | Self-contained: `useSignalHistory()` hook, per-antenna NDJSON, metric toggle, time range |
| **Speedtest Dialog** | `speedtest-dialog.tsx` | ✅ Done | On-demand via `speedtest_*.sh` CGI endpoints, no modem interaction |

### Cellular Information Page (`/cellular`) — ✅ COMPLETE

| Component | File | Status | Data Source |
|-----------|------|--------|-------------|
| **Cellular Information** | `cell-data.tsx` | ✅ Done | `data.network` (ISP, APN, type, CA, bandwidth, WAN IP, DNS) + `data.lte`/`data.nr` (Cell ID, TAC) + `data.device` (MIMO) |
| **Active Bands** | `active-bands.tsx` | ✅ Done | Per-carrier QCAINFO data. Accordion UI with signal bars, badges (LTE/NR, PCC/SCC), bandwidth, EARFCN, PCI. |

**Cellular Information card — implementation details:**

- Parent `cellular-information.tsx` is `"use client"`, calls `useModemStatus()`, passes data down
- 12 rows: ISP, APN (+ Edit link → `/cellular/settings/apn-management`), Network Type, Cell ID (tooltip: eNodeB/gNodeB + Sector), TAC (tooltip: hex), Total Bandwidth (tooltip: per-band breakdown), Carrier Aggregation, Active MIMO, WAN IPv4, WAN IPv6 (truncated + tooltip), Primary DNS, Secondary DNS
- SA-aware: Cell ID/TAC sourced from `nr` in SA mode, `lte` otherwise
- Loading skeleton, null handling, monospace fonts for IP/DNS

**Backend tasks completed for this card:**

| Task | Description | Status |
|------|-------------|--------|
| Cell ID + TAC parsing | `_compute_cell_parts()` / `_hex_to_dec()` in `parse_at.sh`, LTE 28-bit and NR 36-bit decomposition | ✅ Done |
| QCAINFO bandwidth | `parse_ca_bandwidth()` in `parse_at.sh`, sums PCC + all SCCs across LTE and NR, builds per-band tooltip string | ✅ Done |
| AT+CGCONTRDP parser | `parse_cgcontrdp()` — extracts APN, primary/secondary DNS from first non-IMS profile | ✅ Done |
| AT+QMAP="WWAN" parser | `parse_wan_ip()` — extracts WAN IPv4 and IPv6, filters all-zero IPv6 as "none" | ✅ Done |
| TypeScript types | Added 7 fields to `NetworkStatus` interface in `types/modem-status.ts` | ✅ Done |
| Frontend wiring | `cell-data.tsx` converted from hardcoded to data-driven with props from `useModemStatus()` | ✅ Done |

**Active Bands card — implementation details:**

- `parse_ca_info()` in `parse_at.sh` extended to build per-carrier JSON array (`t2_carrier_components`)
- Parses LTE PCC/SCC lines (field pos: type,freq,bw_rb,band,state,PCI,RSRP,RSRQ,RSSI,RSSNR)
- Parses NR lines in two forms: short (5–8 fields) and long (9–12 fields, with UL info)
- NR_SNR converted from raw /100 to actual dB (3GPP spec) via awk
- Sanitizes empty/dash/non-numeric values → `null`
- Frontend: Accordion with expandable per-band detail. Technology badge (LTE=green, NR=blue, with duplex mode), PCC/SCC badge, signal progress bars with quality coloring, bandwidth/EARFCN/PCI/frequency info rows
- `signalToProgress()` utility maps signal dBm/dB to 0–100% using threshold ranges
- `lib/earfcn.ts` shared utility: EARFCN/NR-ARFCN → DL/UL frequency calculation (3GPP TS 36.101 + 38.104), band name lookup, duplex mode lookup. Handles NR band overlap ambiguity by accepting optional band hint.

| Task | Description | Status |
|------|-------------|--------|
| QCAINFO per-carrier parsing | Extended `parse_ca_info()` to output JSON array with per-band details | ✅ Done |
| NR_SNR conversion | Raw /100 conversion for NR SNR values in awk | ✅ Done |
| Poller state + JSON output | `t2_carrier_components` state var, written to `network.carrier_components` in cache | ✅ Done |
| TypeScript types | `CarrierComponent` interface, `carrier_components` in `NetworkStatus`, `signalToProgress()` | ✅ Done |
| Frontend wiring | Accordion UI with signal metrics, badges, loading/empty states | ✅ Done |
| EARFCN utility (`lib/earfcn.ts`) | DL/UL frequency calc, band name lookup, duplex mode. LTE (3GPP TS 36.101) + NR (3GPP TS 38.104 global raster). NR overlap resolution via band hint. | ✅ Done |
| Active Bands enhancements | Badge shows duplex mode (FDD/TDD/SDL). Accordion header shows EARFCN. Expanded detail shows Band Name, DL Frequency, UL Frequency. | ✅ Done |

### Custom SIM Profiles (`/cellular/custom-profiles`) — ✅ COMPLETE

Full CRUD + async apply pipeline for SIM identity/connectivity profiles.

| Component | File | Status | Notes |
|-----------|------|--------|-------|
| **Profile Form** | `custom-profile-form.tsx` | ✅ Done | Create/edit form. MNO presets, APN/CID/PDP, IMEI, TTL/HL. "Load Current SIM" pre-fill via `useCurrentSettings`. Render-time state sync (no useEffect). |
| **Profile List** | `custom-profile-table.tsx` | ✅ Done | Data table with Activate/Edit/Delete actions, active badge. |
| **Profile View** | `custom-profile-view.tsx` | ✅ Done | Card wrapper. Toggles between table and empty state. |
| **Page Coordinator** | `custom-profile.tsx` | ✅ Done | Owns 3 hooks (`useSimProfiles`, `useProfileApply`, `useCurrentSettings`). Confirmation dialog, progress dialog. |
| **Apply Progress** | `apply-progress-dialog.tsx` | ✅ Done | Generic step-by-step progress dialog. Reads step names from state file. |

**Backend:**

| File | Purpose | Status |
|------|---------|--------|
| `profile_mgr.sh` | CRUD library (list, get, save, delete, validate). BusyBox-safe JSON construction. 10-profile limit. | ✅ Done |
| `qmanager_profile_apply` | Detached 3-step apply: APN → TTL/HL → IMEI. Smart diffing (skips unchanged). Modem reboot handling for IMEI. | ✅ Done |
| `profiles/list.sh` | GET — profiles array + active ID | ✅ Done |
| `profiles/get.sh` | GET — single profile JSON | ✅ Done |
| `profiles/save.sh` | POST — create/update | ✅ Done |
| `profiles/delete.sh` | POST — delete + cleanup | ✅ Done |
| `profiles/apply.sh` | POST — async spawn via setsid | ✅ Done |
| `profiles/apply_status.sh` | GET — read state file | ✅ Done |
| `profiles/current_settings.sh` | GET — APN/IMEI/ICCID from modem | ✅ Done |

**Architecture note:** Band locking and network mode were removed from SIM Profiles. Profiles are identity-only: APN, IMEI, TTL/HL. Radio/RF configuration (bands, network mode) is owned by Connection Scenarios.

### Connection Scenarios (`/cellular/custom-profiles/connection-scenarios`) — ✅ COMPLETE

Radio/RF configuration layer. Controls modem network mode via `AT+QNWPREFCFG="mode_pref"`.

| Component | File | Status | Notes |
|-----------|------|--------|-------|
| **Scenario Cards** | `scenario-item.tsx` | ✅ Done | Gradient cards with SVG patterns, active ring, delete for custom. |
| **Active Config** | `active-config-card.tsx` | ✅ Done | Shows active scenario config (bands, mode, optimization). "Applying…" badge during activation. |
| **Add Dialog** | `connection-scenario-card.tsx` | ✅ Done | Create custom scenario with name, description, gradient theme picker. |
| **Page Coordinator** | `connection-scenario-card.tsx` | ✅ Done | Owns `useConnectionScenarios` hook. Wires activation to backend. Toast feedback. |

**Default scenarios (built-in, cannot be edited/deleted):**

| Scenario | AT Command | Behavior |
|----------|------------|----------|
| **Balanced** | `AT+QNWPREFCFG="mode_pref",AUTO` | Modem decides. Band Locking page governs. |
| **Gaming** | `AT+QNWPREFCFG="mode_pref",NR5G` | Force SA only (lowest latency). |
| **Streaming** | `AT+QNWPREFCFG="mode_pref",LTE:NR5G` | SA + NSA + LTE fallback (max bandwidth). |

**Backend:**

| File | Purpose | Status |
|------|---------|--------|
| `scenarios/activate.sh` | POST — maps scenario ID → AT mode_pref command via `qcmd`, persists to `/etc/qmanager/active_scenario` | ✅ Done |
| `scenarios/active.sh` | GET — reads active scenario ID, defaults to "balanced" | ✅ Done |

**Architecture note:** Activation is synchronous (single AT command, ~200ms) — no async pipeline or progress dialog needed. Custom scenarios (`custom-*`) are client-side only for now; backend activation returns `not_implemented`.

---

## Remaining Work

### Pages

| # | Task | Status | Notes |
|---|------|--------|-------|
| 1 | **Active Bands card** | ✅ Done | Per-carrier QCAINFO parser rework. JSON array with band/earfcn/bw/pci/rsrp/rsrq/sinr per CC. NR_SNR /100 conversion. `lib/earfcn.ts` for DL/UL freq calc + band name + duplex mode. |
| 2 | **Terminal Page** | ⬜ TODO | Wire to `send_command.sh` CGI endpoint (POST). Block `QSCAN` with user-facing message. |
| 3 | **Cell Scanner Page** | ⬜ TODO | Dedicated endpoint for `AT+QSCAN` with progress indicator and long-command flag coordination. |
| 4 | **Band Locking / APN Management** | ⬜ TODO | Write-path CGI endpoints (currently only read-path exists). |

### Watchcat & Recovery

| # | Task | Status | Notes |
|---|------|--------|-------|
| 5 | **Build `qmanager_watchcat`** | ⬜ TODO | State machine daemon: MONITOR→SUSPECT→RECOVERY→COOLDOWN→LOCKED. Reads ping data, tiered recovery (ifup → AT+CFUN → reboot). Token-bucket bootloop protection. |
| 6 | **Wire watchcat state to UI** | ⬜ TODO | Status indicator: watchcat state, failure count, last recovery action. |
| 7 | **Rename watchcat lock** | ⬜ TODO | `/tmp/qmanager.lock` → `/tmp/qmanager_watchcat.lock` to avoid collision with serial port lock. |

### Connection Scenarios — Deferred Enhancements

| # | Task | Status | Notes |
|---|------|--------|-------|
| 10 | **Band Locking page interaction** | ⬜ DEFERRED | When a non-Balanced scenario is active (Gaming, Streaming, custom), the Band Locking page (`/cellular/settings/band-locking`) and Network Mode component should disable their input fields and show a banner: "Network mode is managed by the active Connection Scenario (Gaming). Switch to Balanced to regain manual control." Balanced scenario = manual mode (user's Band Locking settings apply). Non-Balanced = override mode (scenario controls network mode, inputs disabled). |
| 11 | **Custom scenario backend persistence** | ⬜ DEFERRED | Currently custom scenarios are client-side only (lost on refresh). Future: `/etc/qmanager/scenarios/<id>.json` storage, CRUD CGI endpoints (`save.sh`, `delete.sh`, `list.sh`), `scenario_mgr.sh` library mirroring `profile_mgr.sh` pattern. |
| 12 | **Custom scenario band locking** | ⬜ DEFERRED | Custom scenarios could configure both network mode AND band locks. Apply script would need multi-step async pipeline (like SIM Profile apply) with `AT+QNWPREFCFG="lte_band"`, `"nsa_nr5g_band"`, `"nr5g_band"` commands. |

### Backend Improvements

| # | Task | Status | Notes |
|---|------|--------|-------|
| 8 | **Error recovery testing** | ⬜ TODO | SIM ejection, modem unresponsive, `sms_tool` crash, stale lock scenarios. |
| 9 | **Long command support** | ⬜ TODO | Verify `AT+QSCAN` flag-based coordination between poller and Cell Scanner page. |

### Completed (Archived)

<details>
<summary>Click to expand completed items</summary>

- ~~Wire `NrStatusComponent`~~ ✅
- ~~Wire `DeviceStatus`~~ ✅
- ~~Wire `DeviceMetricsComponent`~~ ✅
- ~~Wire `SignalHistoryComponent`~~ ✅
- ~~Build `qmanager_ping`~~ ✅ — Unified ping daemon, dual-target ICMP, hysteresis, ring buffer
- ~~Integrate ping data into poller~~ ✅ — `read_ping_data()`, staleness check, connectivity merge
- ~~Wire Internet badge~~ ✅ — Three-state badge in `network-status.tsx`
- ~~Update init script~~ ✅ — Multi-instance procd
- ~~Fix connection uptime~~ ✅ — Keyed off ping daemon, three-state logic
- ~~Build Live Latency component~~ ✅ — Line chart, stats grid, Online/Offline badge
- ~~NR MIMO layers~~ ✅ — Moved to Tier 2, `nr5g_mimo_layers` (not `nr_mimo_layers`)
- ~~TA-based cell distance~~ ✅ — LTE + NR, 3GPP formulas, BusyBox-safe parsing
- ~~NSA SCS parsing~~ ✅ — Fixed `\r` carriage return on last CSV field
- ~~Active Bands card~~ ✅ — Per-carrier QCAINFO parser rework, JSON array output, NR_SNR /100 conversion, accordion UI, `lib/earfcn.ts` (DL/UL frequency, band name, duplex mode), badge shows FDD/TDD
- ~~Custom SIM Profiles~~ ✅ — Full CRUD + async 3-step apply (APN→TTL/HL→IMEI). Backend: `profile_mgr.sh` library, `qmanager_profile_apply` detached script, 9 CGI endpoints. Frontend: form with MNO presets, table with actions, apply progress dialog, 3 hooks. Band locking removed — identity-only profiles.
- ~~Connection Scenarios~~ ✅ — 3 default scenarios (Balanced/Gaming/Streaming) mapped to `AT+QNWPREFCFG="mode_pref"`. Synchronous activation (single AT command). Backend: `activate.sh` + `active.sh` CGI endpoints. Frontend: `useConnectionScenarios` hook wired to existing gradient card UI. Toast feedback, activation guard.
- ~~Band removal from SIM Profiles~~ ✅ — Stripped `network_mode`, `lte_bands`, `nsa_nr_bands`, `sa_nr_bands`, `band_lock_enabled` from all layers (types, hooks, form, backend scripts, CGI endpoints). Cleaned dead validators and stale step labels.

</details>

---

## Component Reference: Network Status

**Props:** `data: NetworkStatus | null`, `modemReachable: boolean`, `isLoading: boolean`, `isStale: boolean`

**Radio Badge Logic:**

| Condition | Display |
|-----------|---------|
| `modemReachable === true` | 🟢 Radio On |
| `modemReachable === false` | 🔴 Radio Off |

**Network Type Circle:**

| Condition | Icon | Label / Sublabel |
|-----------|------|------------------|
| `5G-NSA` | `MdOutline5G` | "5G Signal" / "5G + LTE" |
| `5G-NSA` + NR CA | `MdOutline5G` | "5G Signal" / "5G + LTE / NR-CA" |
| `5G-SA` | `MdOutline5G` | "5G Signal" / "Standalone" |
| `LTE` + CA | `Md4gPlusMobiledata` | "LTE+ Signal" / "4G Carrier Aggregation" |
| `LTE` no CA | `Md4gMobiledata` | "LTE Signal" / "4G Connected" |
| No 4G/5G | `Md3gMobiledata` (dimmed) | "Signal" / "No 4G/5G" |

## Component Reference: Recent Activities — Event Severity Model

Events are **positive** (green ✅) or **negative** (red ❌). Frontend maps `info` → check, `warning`/`error` → X.

**Positive** (`severity: "info"`): modem signal restored, network mode upgrade, 5G NR anchor acquired, CA activated, carrier count increased, internet restored, band change, cell handoff.

**Negative** (`severity: "warning"`): modem unreachable, network mode downgrade, 5G NR anchor lost, CA deactivated, carrier count decreased, internet lost.

**Downgrade detection:** `case` match on `"$prev-$current"` pairs. `5G-SA-5G-NSA`, `5G-SA-LTE`, `5G-NSA-LTE` → warning. Carrier count decrease → warning.

---

*End of Task Tracker*
