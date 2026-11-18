# Phase 3.2.4 — Report 04: Backup, Restore Safety & Disaster Recovery Engineering

## 1. Executive Summary

This report delivers an engineering and safety audit of the proposed `pg_dump` backup and restore procedure for `parent-control-prod`.

It identifies the operational constraints, cryptographic requirements, and dangerous disaster scenarios associated with database restores. Most critically, it documents why destructive flags like `--clean --if-exists` must **never** be executed against a live production database.

---

## 2. PostgreSQL Connection & Network Architecture

### 1. Endpoint Configuration
- **Supabase Host:** `aws-0-ap-northeast-2.pooler.supabase.com`
- **Port:**
  - `6543`: Transaction Pooler (Supavisor) — Recommended for stateless queries. Note that `pg_dump` requires session-level features and cursor preservation.
  - `5432`: Direct Connection / Session Pooler — **Required for `pg_dump`**.
- **User:** `postgres.hhqgreaoqulmfwfwarhc`
- **Database:** `postgres`
- **TLS Requirement:** **MANDATORY (`sslmode=require`)**. Supabase rejects any non-TLS connection attempts.

### 2. Credential Security Handling
- **Forbidden Practice:** Database passwords must **never** be passed as inline CLI flags (e.g. `-W` or `-d postgres://...:password@...`), which are visible to all users via process listing commands (`ps aux`, `Get-Process`).
- **Sanctioned Practice:** Pass the database password via the `PGPASSWORD` environment variable or a local `~/.pgpass` file with strict POSIX permissions (`chmod 600`).

---

## 3. Schema & Data Scope: The `auth` Boundary Trap

A common failure mode in Supabase disaster recovery is backing up only the `public` schema.

### Analysis of Schemas:
1. **`public` Schema:** Contains application entities (`devices`, `families`, `location_events`, etc.).
2. **`private` Schema:** Contains internal security functions, triggers, and state helpers.
3. **`auth` Schema:** Managed by Supabase GoTrue; contains `auth.users`, hashed passwords, email verification tokens, and identities.

> [!CAUTION]
> If an operator executes `pg_dump --schema=public`, the entire `auth.users` table is **OMITTED**.
> Restoring such a backup results in orphaned records: `public.profiles` foreign keys (`id REFERENCES auth.users(id) ON DELETE CASCADE`) will fail or delete all profiles immediately!
> 
> **Requirement:** Both `public` and `private` schemas must be captured. In addition, user identity exports via Supabase CLI (`supabase db dump --data-only`) or Auth Admin API must be scheduled to preserve account sign-in capability.

---

## 4. Preservation of RLS, Triggers, and Constraints

Standard `pg_dump` output preserves:
- Table structures, column definitions, and primary/foreign keys.
- `ALTER TABLE ... ENABLE ROW LEVEL SECURITY;`
- All `CREATE POLICY` statements and expressions.
- Table and column-level `GRANT` and `REVOKE` statements.
- `CREATE TRIGGER` and custom stored procedures.

When restored, PostgreSQL rebuilds the exact authorization and RLS posture defined in production.

---

## 5. CRITICAL DANGER: `--clean --if-exists` Destructive Risk

In the Phase 3.2.3 recommendations, the sample command included:
```bash
pg_dump ... --clean --if-exists ...
```

### Why `--clean --if-exists` is Hazardous:
1. **What the flag generates in SQL:**
   ```sql
   DROP TABLE IF EXISTS public.devices CASCADE;
   DROP TABLE IF EXISTS public.families CASCADE;
   DROP TABLE IF EXISTS public.profiles CASCADE;
   ```
2. **The Disaster Scenario (Accidental Production Target):**
   - If a developer or automated script attempts to test a "restore" and accidentally points the `psql -f dump.sql` command at the production database connection string instead of a local test container:
   - **THE ENTIRE PRODUCTION DATABASE IS INSTANTLY DROPPED AND OVERWRITTEN.**
   - All live enrolled devices, family memberships, and real-time logs are wiped.
3. **Mandatory Safety Rule:**
   - **Never run a restore script containing `DROP` or `--clean` against production.**
   - Restore drills must be restricted to a locally hosted PostgreSQL instance (`127.0.0.1:54322`) or a dedicated staging project.

---

## 6. Recommended Safe Backup Script Specification

A production-grade backup script must enforce:
1. **Zero Password Leakage:** Read password from `.tools/supabase-db-password.txt` without printing or passing in CLI args.
2. **Schema Inclusions:** Include `--schema=public` and `--schema=private`.
3. **At-Rest Encryption:** Pipe `pg_dump` directly into GPG (AES-256) before writing to disk:
   ```bash
   pg_dump "sslmode=require host=aws-0-ap-northeast-2.pooler.supabase.com port=5432 dbname=postgres user=postgres.hhqgreaoqulmfwfwarhc" \
     --schema=public --schema=private --no-owner --no-privileges \
     | gpg --symmetric --cipher-algo AES256 --output "backup_$(date +%Y%m%d).sql.gpg"
   ```
4. **Offsite Synchronization:** Upload the encrypted `.sql.gpg` artifact to a dedicated secure storage bucket (e.g. AWS S3 Glacier or Cloudflare R2) with a 30-day lifecycle retention rule.
