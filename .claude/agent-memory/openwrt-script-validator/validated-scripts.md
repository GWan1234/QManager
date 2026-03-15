---
name: validated-scripts
description: Scripts that have been audited for OpenWRT/BusyBox compatibility and their status
type: project
---

## Validated Scripts

### 2026-03-15 — Email Alerts Feature (Final Audit: 3 scripts, all PASS)

| Script | Status | LF | Multi-var | jq Safety | Issues |
|--------|--------|----|----|---|--------|
| `scripts/usr/lib/qmanager/email_alerts.sh` | **✅ PASS** | ✓ | ✓ Split (118–120) | ✓ Safe null-handling | 0 |
| `scripts/cgi/quecmanager/monitoring/email_alerts.sh` | **✅ PASS** | ✓ | N/A | ✓ Safe `// empty` on strings | 0 |
| `scripts/debug_email_alerts.sh` | **✅ PASS** | ✓ | N/A | ✓ N/A | 0 |

**Library (email_alerts.sh) Details:**
- Lines 118–120: ONE VAR PER LINE (BusyBox ash requirement) ✓
- Lines 163–185: Retry logic (while loop, 3 attempts, 10s sleep) — all POSIX, clean exit flow ✓
- Line 232: Error capture `2>/tmp/msmtp_last_err.log` + line 239 safe retrieval via `local err_detail` ✓
- jq: `.enabled | if . == null then "false"` (explicit null→false, safe) ✓
- HTML heredocs: Variables properly interpolated in email templates ✓

**CGI Endpoint Details:**
- Line 133: `tls_trust_file /etc/ssl/certs/ca-certificates.crt` present (Gmail STARTTLS requirement) ✓
- Line 87: `jq '.app_password // empty'` safe (empty handles null in password context; password is string-only) ✓
- Line 96–105: Threshold validation loop (1–60 range, numeric guard) — clean POSIX case/numeric check ✓

**Debug Script Details:**
- Comprehensive pre-flight (library, config, processes, jq fix check) ✓
- CFUN=0/1 simulation with state sampling ✓
- Diagnostic logic (jq bug detection, LONG_FLAG check, msmtp log diff) ✓
- All read-only except `touch` for test flag ✓

**Total issues: 0 (all severity levels)**
**Recommendation: Ready to commit**

### 2026-03-15 — Full daemon audit (qmanager_ping + qmanager_poller + email_alerts.sh)

| Script | Status | Issues Found | Fixed? |
|--------|--------|-------------|--------|
| `scripts/usr/bin/qmanager_ping` | PASS | No issues — clean POSIX sh, LF, one-var-per-local | N/A |
| `scripts/usr/bin/qmanager_poller` | PASS (after fix) | 6× multi-var `local` (C); `jq // empty` on `.timestamp` (W) | Yes — split to one per line; replaced with `if . == null then empty` |
| `scripts/usr/lib/qmanager/email_alerts.sh` | PASS (after fix) | `local trigger status recipient` multi-var in `_ea_log_event()` (C) | Yes — split to one per line |

Fixed lines in `qmanager_poller`:
- `local cur_idle cur_total` → split (update_proc_metrics)
- `local diff_idle diff_total` → split (update_proc_metrics)
- `local mem_total mem_available` → split (update_proc_metrics)
- `local lte_mimo_result nr_mimo_result` → split ×2 (collect_boot_data, poll_tier2)
- `local ping_ts now age` → split; `// empty` → `if . == null then empty else tostring end` (read_ping_data)
