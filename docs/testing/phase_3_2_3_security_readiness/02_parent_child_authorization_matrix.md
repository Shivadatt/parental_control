# Phase 3.2.3 — Report 02: Parent vs. Child Authorization Matrix

## 1. Executive Summary

This report establishes the comprehensive authorization matrix defining permitted CRUD (Create, Read, Update, Delete) capabilities across the four system roles:
1. **Parent Account** (Authenticated parent user)
2. **Child Account** (Authenticated child user)
3. **Anonymous Caller** (`anon` key without valid user JWT)
4. **Service Role** (Backend Deno Edge Functions / Trusted engine)

---

## 2. Comprehensive Role-Based Matrix

| Table / Resource | Operation | Parent | Child | Anonymous | Service Role | Enforcement Mechanism |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| **`profiles`** | SELECT | Self & Family | Self & Family | DENIED | Full | RLS `profiles_select_self_or_family` |
| | UPDATE | Display Name Only | Display Name Only | DENIED | Full | RLS `profiles_update_self` + Grant + Trigger |
| | INSERT / DELETE | DENIED | DENIED | DENIED | Full | Handled via Auth Triggers & Functions |
| **`families`** | SELECT | Own Family | Own Family | DENIED | Full | RLS `families_select_members` |
| | UPDATE | Owner Only (Name/Settings) | DENIED | DENIED | Full | RLS `families_update_owner` + Trigger |
| | INSERT / DELETE | Edge Function | DENIED | DENIED | Full | `family-admin` / `account` Function |
| **`family_members`** | SELECT | Family Co-members | Family Co-members | DENIED | Full | RLS `family_members_select_family` |
| | MUTATE | Edge Function | DENIED | DENIED | Full | `family-admin` Function |
| **`devices`** | SELECT | Family Devices | Own Device Only | DENIED | Full | RLS `devices_select_parent_or_child` (Excludes `secret_hash`) |
| | UPDATE | Via Edge Function | Heartbeat Via EF | DENIED | Full | `device-policy` / `device-telemetry` |
| | DELETE | Via Edge Function | DENIED | DENIED | Full | `family-admin` (Revocation) |
| **`device_pairing_tokens`** | ALL | DENIED (0 policies) | DENIED (0 policies) | DENIED | Full | Service-role only table |
| **`pairing_requests`** | SELECT | Participants | Participants | DENIED | Full | RLS `pairing_requests_select_participants` |
| | MUTATE | Edge Function | Edge Function | DENIED | Full | `pairing` Function Handshake |
| **`device_policies`** | SELECT | Family Devices | Own Device Only | DENIED | Full | RLS `device_policies_select_parent_or_child` |
| | MUTATE | Via Edge Function | DENIED | DENIED | Full | `device-policy` Function |
| **`device_commands`** | SELECT | Family Devices | Own Device Only | DENIED | Full | RLS `device_commands_select_parent_or_child` |
| | INSERT | Via Edge Function | DENIED | DENIED | Full | `device-command` Function |
| | UPDATE (Ack) | DENIED | Via Edge Function | DENIED | Full | `device-command` (action: "poll/ack") |
| **`usage_daily`** | SELECT | Family Devices | Own Device Only | DENIED | Full | RLS `usage_daily_select_parent_or_child` |
| | INSERT / UPDATE | DENIED | Via Edge Function | DENIED | Full | `device-telemetry` (HMAC authenticated) |
| **`location_events`** | SELECT | Family Devices | Own Device Only | DENIED | Full | RLS `location_events_select_parent_or_child` |
| | INSERT | DENIED | Via Edge Function | DENIED | Full | `device-telemetry` (HMAC authenticated) |
| **`device_apps`** | SELECT | Family Devices | Own Device Only | DENIED | Full | RLS `device_apps_select_parent_or_child` |
| | MUTATE | Via Edge Function | Via Edge Function | DENIED | Full | `device-policy` & `device-telemetry` |
| **`safe_zones`** | SELECT | Family Zones | Family Zones | DENIED | Full | RLS `safe_zones_select_family` |
| | INSERT / UPDATE | Allowed (Parent) | DENIED | DENIED | Full | RLS `safe_zones_insert_parent`, `safe_zones_update_parent` |
| | DELETE | Via Edge Function | DENIED | DENIED | Full | `family-admin` (action: "delete_zone") |
| **`safe_zone_states`** | ALL | DENIED (0 policies) | DENIED (0 policies) | DENIED | Full | System table, updated via RPC |
| **`safety_alerts`** | SELECT | Family Alerts | Own Device Alerts | DENIED | Full | RLS `safety_alerts_select_parent_or_child` |
| | INSERT | Via Edge Function | Via Edge Function | DENIED | Full | `device-telemetry` (SOS events) |
| **`remote_sessions`** | SELECT | Family Sessions | Own Sessions | DENIED | Full | RLS `remote_sessions_select_participants` |
| | MUTATE | Via Edge Function | Via Edge Function | DENIED | Full | `remote-session` Function |
| **`webrtc_signals`** | SELECT | Session Participant | Session Participant | DENIED | Full | RLS `webrtc_signals_select_participant` |
| | INSERT | Session Participant | Session Participant | DENIED | Full | RLS `webrtc_signals_insert_participant` |
| **`audit_logs`** | SELECT | Family Logs | DENIED | DENIED | Full | RLS `audit_logs_select_family_parent` |
| | MUTATE | BLOCKED | BLOCKED | BLOCKED | Append Only | Trigger `audit_logs_append_only` |
| **`child_contact_ids`**| ALL | DENIED (0 policies) | DENIED (0 policies) | DENIED | Full | Service-role only table |
| **`pairing_attempts`** | ALL | DENIED (0 policies) | DENIED (0 policies) | DENIED | Full | Anti-brute force service-role table |

---

## 3. Analysis of Critical Security Invariants

1. **Child Tamper Resistance**:
   - A child account cannot delete policies, alter safe zones, create commands, inspect parents' audit logs, or see siblings' coordinates.
   - Child telemetry cannot be forged through PostgREST; all location and usage ingestion requires physical device HMAC signature verified by `device-telemetry`.
2. **Parent Boundary Isolation**:
   - Parents cannot access devices, policies, location, or logs outside their active family.
   - Parent accounts cannot escalate to platform administrators or read other families' records.
3. **Audit Trail Completeness**:
   - Audit logs cannot be updated or deleted by anyone (including parents and service-role updates), guaranteeing tamper-proof forensic logging.
