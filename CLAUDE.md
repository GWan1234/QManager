## Device & Architecture Context

QManager is a Next.js (static export) frontend + OpenWRT CGI shell backend, deployed **onto the modem itself** (Quectel RM520N/RM551E/RM500Q-class running OpenWRT). Backend = BusyBox `/bin/sh` scripts under `scripts/www/cgi-bin/`, daemons under `scripts/usr/bin/`, shared libs under `scripts/usr/lib/qmanager/`. Modem talks via `qcmd` AT-command wrapper. Because the app runs on the device, anything that reboots the modem also kills any in-flight HTTP request — defer reboots via dialog + persistent banner, never `AT+CFUN=1,1` mid-request.

See `docs/ARCHITECTURE.md`, `docs/BACKEND.md`, `docs/FRONTEND.md`, `docs/API-REFERENCE.md` for full breakdowns.

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
