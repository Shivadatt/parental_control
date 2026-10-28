-- Parent Control — permanent Child ID.
--
-- The Child ID is a stable, shareable *identifier* for a child account. It is
-- deliberately not an authentication credential: knowing it lets a verified
-- parent open a normal pairing request, which the child must still approve.
-- Every data path continues to be authorised by the user JWT, the family
-- membership and (for telemetry) the device credential.
--
-- Additive only. No existing row, relationship or token is rewritten.

-- ---------------------------------------------------------------------------
-- child_contact_ids
-- ---------------------------------------------------------------------------
-- Service-role only: RLS enabled with zero policies and no client grants, the
-- same posture as device_pairing_tokens and pairing_attempts. The value is
-- returned exclusively by the pairing Edge Function to the owning child
-- (auth.uid()), never to a parent or a stranger.
create table public.child_contact_ids (
  child_user_id uuid primary key references public.profiles (id) on delete cascade,
  -- Canonical form "PC" + 8 unambiguous characters, e.g. PC7K4M2QRX.
  -- Display form is PC-7K4M2QRX; the dash is stripped before lookup.
  contact_id text not null unique
    check (contact_id ~ '^PC[23456789ABCDEFGHJKMNPQRSTVWXYZ]{8}$'),
  created_at timestamptz not null default now(),
  rotated_at timestamptz
);

comment on table public.child_contact_ids is
  'Stable child identifier used to initiate pairing. Identifier only, never a credential.';
comment on column public.child_contact_ids.contact_id is
  'Canonical Child ID. One per account, assigned once, never regenerated on launch.';

alter table public.child_contact_ids enable row level security;
revoke all on public.child_contact_ids from public, anon, authenticated;
grant select, insert, update, delete on public.child_contact_ids to service_role;

-- ---------------------------------------------------------------------------
-- device_pairing_tokens.purpose
-- ---------------------------------------------------------------------------
-- A token minted by the child ("code") is a secret the child shows on screen.
-- A token minted by the server when a parent invites ("invite") is internal and
-- never leaves the server; it exists only to keep the single-use, replay-proof
-- request row. Separating them stops a legacy code mint from revoking a live
-- invite the child has not answered yet.
alter table public.device_pairing_tokens
  add column purpose text not null default 'code'
    check (purpose in ('code', 'invite'));

comment on column public.device_pairing_tokens.purpose is
  'code = child-initiated short-lived secret; invite = server-minted for a Child ID invite.';

create index device_pairing_tokens_child_purpose_idx
  on public.device_pairing_tokens (child_user_id, purpose, status);
