-- Development-friendly RLS policies (open for anon role)
-- Enable RLS but allow anon to perform required operations for the SPA to function.

-- Enable RLS
alter table public.reservations enable row level security;
alter table public.products enable row level security;
alter table public.bookings enable row level security;

-- Drop existing permissive policies if needed (ignore errors if none)
do $$ begin
  execute 'drop policy if exists reservations_select_all on public.reservations';
  execute 'drop policy if exists reservations_insert_all on public.reservations';
  execute 'drop policy if exists reservations_update_all on public.reservations';
  execute 'drop policy if exists reservations_delete_all on public.reservations';
  execute 'drop policy if exists products_select_all on public.products';
  execute 'drop policy if exists products_insert_all on public.products';
  execute 'drop policy if exists products_update_all on public.products';
  execute 'drop policy if exists products_delete_all on public.products';
  execute 'drop policy if exists bookings_select_all on public.bookings';
  execute 'drop policy if exists bookings_insert_all on public.bookings';
  execute 'drop policy if exists bookings_update_all on public.bookings';
  execute 'drop policy if exists bookings_delete_all on public.bookings';
exception when others then null; end $$;

-- Reservations
create policy reservations_select_all on public.reservations for select using (true);
create policy reservations_insert_all on public.reservations for insert with check (true);
create policy reservations_update_all on public.reservations for update using (true) with check (true);
create policy reservations_delete_all on public.reservations for delete using (true);

-- Products
create policy products_select_all on public.products for select using (true);
create policy products_insert_all on public.products for insert with check (true);
create policy products_update_all on public.products for update using (true) with check (true);
create policy products_delete_all on public.products for delete using (true);

-- Bookings
create policy bookings_select_all on public.bookings for select using (true);
create policy bookings_insert_all on public.bookings for insert with check (true);
create policy bookings_update_all on public.bookings for update using (true) with check (true);
create policy bookings_delete_all on public.bookings for delete using (true);

