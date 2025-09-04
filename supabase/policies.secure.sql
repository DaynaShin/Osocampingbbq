-- Secure RLS policies (recommended for production with server-side admin)
-- Requires authenticated users and separates read/write permissions.
-- NOTE: The current SPA uses anon key in the browser and cannot satisfy these policies by itself.
-- To use this set, route admin actions through a server with service role key.

-- Enable RLS
alter table public.reservations enable row level security;
alter table public.products enable row level security;
alter table public.bookings enable row level security;

-- Example roles
-- create role app_user noinherit;         -- supabase auth users
-- create role app_admin noinherit;        -- service role (server)

-- Cleanup old policies (ignore errors)
do $$ begin
  execute 'drop policy if exists reservations_select_public on public.reservations';
  execute 'drop policy if exists reservations_insert_public on public.reservations';
  execute 'drop policy if exists reservations_update_admin on public.reservations';
  execute 'drop policy if exists reservations_delete_admin on public.reservations';
  execute 'drop policy if exists products_select_public on public.products';
  execute 'drop policy if exists products_crud_admin on public.products';
  execute 'drop policy if exists bookings_select_admin on public.bookings';
  execute 'drop policy if exists bookings_crud_admin on public.bookings';
exception when others then null; end $$;

-- Reservations: allow public to insert and read; admin can update/delete
create policy reservations_select_public on public.reservations for select using (true);
create policy reservations_insert_public on public.reservations for insert with check (true);
create policy reservations_update_admin on public.reservations for update using (auth.role() = 'service_role') with check (auth.role() = 'service_role');
create policy reservations_delete_admin on public.reservations for delete using (auth.role() = 'service_role');

-- Products: public can select; only admin can modify
create policy products_select_public on public.products for select using (true);
create policy products_crud_admin on public.products for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');

-- Bookings: only admin can read/write (contains pricing/customer PII)
create policy bookings_select_admin on public.bookings for select using (auth.role() = 'service_role');
create policy bookings_crud_admin on public.bookings for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');

