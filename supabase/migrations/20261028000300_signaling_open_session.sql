-- Signaling for consented sessions after parent-controlled lifetime.
--
-- `20261028000200_parent_controlled_session_lifetime.sql` made `expires_at`
-- nullable and clears it when a child consents, because a consented session is
-- parent-controlled and has no fixed deadline. It also keeps a legacy
-- accepted/active row alive when it still carries a past deadline: elapsed time
-- no longer terminates a consented session.
--
-- The original `webrtc_signals` policies still required `s.expires_at >
-- now()`, which is NULL for consented sessions (and in the past for legacy
-- ones), so neither participant could insert an offer, answer or ICE candidate
-- and media could not be established at all.
--
-- The deadline predicate is removed. `expires_at` is a pending-request
-- deadline only; the policies already require status `accepted` or `active`,
-- so a pending, ended, declined or expired session still cannot carry
-- signaling, and a non-participant still cannot read or write another
-- session's signals.
--
-- Rollback: re-create the two policies from
-- 20260101000200_rls.sql (with `s.expires_at > now()`).

drop policy if exists webrtc_signals_select_participant
  on public.webrtc_signals;
create policy webrtc_signals_select_participant
  on public.webrtc_signals
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.remote_sessions s
      where s.id = session_id
        and s.status in ('accepted', 'active')
        and (s.parent_user_id = auth.uid() or s.child_user_id = auth.uid())
    )
  );

drop policy if exists webrtc_signals_insert_participant
  on public.webrtc_signals;
create policy webrtc_signals_insert_participant
  on public.webrtc_signals
  for insert
  to authenticated
  with check (
    from_user_id = auth.uid()
    and exists (
      select 1
      from public.remote_sessions s
      where s.id = session_id
        and s.status in ('accepted', 'active')
        and (s.parent_user_id = auth.uid() or s.child_user_id = auth.uid())
    )
  );
