-- Parent Control — explicit server-role privileges.
--
-- BYPASSRLS skips policies but does not grant table or sequence privileges.
-- Edge Functions use the service-role client for every write, so the server role
-- needs explicit grants on top of the client grants in 20260101000200_rls.sql.
-- anon and authenticated keep exactly the privileges granted there; RLS stays
-- enabled on every table.

grant usage on schema public to service_role;

grant select, insert, update, delete on all tables in schema public to service_role;
grant usage, select on all sequences in schema public to service_role;

alter default privileges in schema public
  grant select, insert, update, delete on tables to service_role;
alter default privileges in schema public
  grant usage, select on sequences to service_role;
