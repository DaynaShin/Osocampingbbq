-- Supabase schema for Osomarketing reservation app (Fixed version)
-- Run this in Supabase SQL editor (or psql) to create tables.

create extension if not exists "uuid-ossp";

-- ============
-- reservations
-- ============
create table if not exists public.reservations (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  phone text not null,
  email text,
  reservation_date date not null,
  reservation_time time not null,
  service_type text,
  message text,
  status text not null default 'pending', -- pending | confirmed | cancelled
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

create index if not exists idx_reservations_date on public.reservations (reservation_date);
create index if not exists idx_reservations_status on public.reservations (status);

-- ============
-- products
-- ============
create table if not exists public.products (
  id uuid primary key default uuid_generate_v4(),
  product_name text not null,
  display_name text,
  product_code text not null unique,
  product_date date not null,  -- 이 컬럼이 빠져있었습니다
  start_time time not null,
  end_time time not null,
  price integer not null default 0,
  description text,
  status text not null default 'active', -- active | inactive
  is_booked boolean not null default false,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

create index if not exists idx_products_date on public.products (product_date);
create index if not exists idx_products_available on public.products (product_date, is_booked, status);

-- ============
-- bookings
-- ============
create table if not exists public.bookings (
  id uuid primary key default uuid_generate_v4(),
  customer_name text not null,
  customer_phone text not null,
  customer_email text,
  booking_date date not null,
  booking_time time not null,
  product_name text not null,
  product_code text,
  guest_count integer not null default 1,
  total_amount integer not null default 0,
  status text not null default 'confirmed', -- pending | confirmed | cancelled | completed
  special_requests text,
  created_at timestamp with time zone default now()
);

create index if not exists idx_bookings_date on public.bookings (booking_date);
create index if not exists idx_bookings_status on public.bookings (status);

-- update trigger for reservations.updated_at
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists reservations_set_updated_at on public.reservations;
create trigger reservations_set_updated_at
before update on public.reservations
for each row execute function public.set_updated_at();

-- update trigger for products.updated_at
drop trigger if exists products_set_updated_at on public.products;
create trigger products_set_updated_at
before update on public.products
for each row execute function public.set_updated_at();