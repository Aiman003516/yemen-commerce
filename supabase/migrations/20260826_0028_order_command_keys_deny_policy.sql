-- The command-key table is private implementation state. Client roles have
-- no table grants; this explicit deny policy also documents that boundary for
-- RLS analysis while SECURITY DEFINER functions retain owner access.
create policy order_command_keys_client_deny
on public.order_command_keys
for all to public
using (false)
with check (false);
