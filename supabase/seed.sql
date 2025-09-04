-- Seed data for Osomarketing reservation app
-- Run in Supabase SQL editor after creating schema.

-- Products: create sample slots for next 5 days
insert into public.products (product_name, display_name, product_code, product_date, start_time, end_time, price, description, status, is_booked)
select
  '상담 슬롯' as product_name,
  concat('오소 상담 ', to_char(current_date + (g.d || ' days')::interval, 'YYYY-MM-DD'), ' ', s.label) as display_name,
  concat('P', to_char(current_date + (g.d || ' days')::interval, 'YYMMDD'), s.code) as product_code,
  (current_date + (g.d || ' days')::interval)::date as product_date,
  s.start_time::time as start_time,
  s.end_time::time as end_time,
  s.price as price,
  s.desc as description,
  'active' as status,
  case when s.code in ('A','C') and g.d in (1,3) then true else false end as is_booked
from (
  values
    ('10:00','11:00','A', 50000, '기본 상담 60분', '오전 10시 슬롯'),
    ('14:00','15:30','B', 80000, '확장 상담 90분', '오후 2시 슬롯'),
    ('16:00','17:00','C', 60000, '마무리 상담 60분', '오후 4시 슬롯')
) as s(start_time, end_time, code, price, desc, label)
cross join (
  values (0),(1),(2),(3),(4)
) as g(d);

-- Reservations: sample requests with varied statuses
insert into public.reservations (name, phone, email, reservation_date, reservation_time, service_type, message, status)
values
  ('김민수', '010-1111-2222', 'ms.kim@example.com', current_date + interval '1 day', '10:00', '마케팅 상담', '채널 운영 초기 전략 상담 요청', 'pending'),
  ('이서연', '010-3333-4444', 'sy.lee@example.com', current_date + interval '1 day', '14:00', '브랜딩 상담', '네이밍/톤앤매너 자문', 'confirmed'),
  ('박지훈', '010-5555-6666', 'jh.park@example.com', current_date + interval '2 day', '16:00', '광고 운영 상담', '퍼포먼스 최적화 문의', 'pending'),
  ('최유진', '010-7777-8888', 'yj.choi@example.com', current_date + interval '3 day', '10:00', '웹사이트 제작', '견적 요청', 'cancelled');

-- Bookings: confirmed booking that corresponds to booked products
insert into public.bookings (customer_name, customer_phone, customer_email, booking_date, booking_time, product_name, product_code, guest_count, total_amount, status, special_requests)
select
  '홍길동' as customer_name,
  '010-9999-0000' as customer_phone,
  'gildong@example.com' as customer_email,
  p.product_date as booking_date,
  p.start_time as booking_time,
  coalesce(p.display_name, p.product_name) as product_name,
  p.product_code,
  1 as guest_count,
  p.price as total_amount,
  'confirmed' as status,
  '샘플 예약 데이터' as special_requests
from public.products p
where p.is_booked = true
limit 2;

