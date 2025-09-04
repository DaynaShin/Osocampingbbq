-- OSO Camping BBQ 실제 데이터 입력
-- 기존 oso_seed_vip_slots.sql 데이터를 통합 스키마에 맞게 개선

BEGIN;

-- ============================================
-- 타임슬롯 데이터 입력
-- ============================================

INSERT INTO public.time_slot_catalog(slot_id, part_name, slot_name, start_local, end_local, duration_minutes, price_multiplier) VALUES 
('T1', '1부', '타임1', '10:00', '13:00', 180, 1.0),
('T2', '2부', '타임2', '14:00', '17:00', 180, 1.2), -- 오후 시간대 20% 할증
('T3', '3부', '타임3', '18:00', '21:00', 180, 1.5)  -- 저녁 시간대 50% 할증
ON CONFLICT (slot_id) DO UPDATE SET 
  part_name = EXCLUDED.part_name, 
  slot_name = EXCLUDED.slot_name, 
  start_local = EXCLUDED.start_local, 
  end_local = EXCLUDED.end_local,
  duration_minutes = EXCLUDED.duration_minutes,
  price_multiplier = EXCLUDED.price_multiplier;

-- ============================================
-- 자원 카탈로그 데이터 입력 (요금 및 상세정보 포함)
-- ============================================

-- 프라이빗룸 (5개)
INSERT INTO public.resource_catalog(internal_code, category_code, label, display_name, active, price, max_guests, description) VALUES 
('PR01', 'PR', '가', '프라이빗룸 가', TRUE, 150000, 6, '독립된 프라이빗 공간으로 소규모 모임에 적합'),
('PR02', 'PR', '나', '프라이빗룸 나', TRUE, 150000, 6, '독립된 프라이빗 공간으로 소규모 모임에 적합'),
('PR03', 'PR', '다', '프라이빗룸 다', TRUE, 150000, 6, '독립된 프라이빗 공간으로 소규모 모임에 적합'),
('PR04', 'PR', '라', '프라이빗룸 라', TRUE, 150000, 6, '독립된 프라이빗 공간으로 소규모 모임에 적합'),
('PR05', 'PR', '마', '프라이빗룸 마', TRUE, 150000, 6, '독립된 프라이빗 공간으로 소규모 모임에 적합')
ON CONFLICT (internal_code) DO UPDATE SET 
  category_code = EXCLUDED.category_code, 
  label = EXCLUDED.label, 
  display_name = EXCLUDED.display_name, 
  active = EXCLUDED.active,
  price = EXCLUDED.price,
  max_guests = EXCLUDED.max_guests,
  description = EXCLUDED.description;

-- 야외 소파테이블 (7개)
INSERT INTO public.resource_catalog(internal_code, category_code, label, display_name, active, price, max_guests, description) VALUES 
('ST01', 'ST', 'A', '야외 소파테이블 A', TRUE, 80000, 4, '야외 테라스의 편안한 소파 테이블'),
('ST02', 'ST', 'B', '야외 소파테이블 B', TRUE, 80000, 4, '야외 테라스의 편안한 소파 테이블'),
('ST03', 'ST', 'C', '야외 소파테이블 C', TRUE, 80000, 4, '야외 테라스의 편안한 소파 테이블'),
('ST04', 'ST', 'D', '야외 소파테이블 D', TRUE, 80000, 4, '야외 테라스의 편안한 소파 테이블'),
('ST05', 'ST', 'E', '야외 소파테이블 E', TRUE, 80000, 4, '야외 테라스의 편안한 소파 테이블'),
('ST06', 'ST', 'F', '야외 소파테이블 F', TRUE, 80000, 4, '야외 테라스의 편안한 소파 테이블'),
('ST07', 'ST', 'G', '야외 소파테이블 G', TRUE, 80000, 4, '야외 테라스의 편안한 소파 테이블')
ON CONFLICT (internal_code) DO UPDATE SET 
  category_code = EXCLUDED.category_code, 
  label = EXCLUDED.label, 
  display_name = EXCLUDED.display_name, 
  active = EXCLUDED.active,
  price = EXCLUDED.price,
  max_guests = EXCLUDED.max_guests,
  description = EXCLUDED.description;

-- 텐트동 (9개)
INSERT INTO public.resource_catalog(internal_code, category_code, label, display_name, active, price, max_guests, description) VALUES 
('TN01', 'TN', '1', '텐트동 1', TRUE, 120000, 8, '넓은 텐트형 공간으로 단체 모임에 적합'),
('TN02', 'TN', '2', '텐트동 2', TRUE, 120000, 8, '넓은 텐트형 공간으로 단체 모임에 적합'),
('TN03', 'TN', '3', '텐트동 3', TRUE, 120000, 8, '넓은 텐트형 공간으로 단체 모임에 적합'),
('TN04', 'TN', '4', '텐트동 4', TRUE, 120000, 8, '넓은 텐트형 공간으로 단체 모임에 적합'),
('TN05', 'TN', '5', '텐트동 5', TRUE, 120000, 8, '넓은 텐트형 공간으로 단체 모임에 적합'),
('TN06', 'TN', '6', '텐트동 6', TRUE, 120000, 8, '넓은 텐트형 공간으로 단체 모임에 적합'),
('TN07', 'TN', '7', '텐트동 7', TRUE, 120000, 8, '넓은 텐트형 공간으로 단체 모임에 적합'),
('TN08', 'TN', '8', '텐트동 8', TRUE, 120000, 8, '넓은 텐트형 공간으로 단체 모임에 적합'),
('TN09', 'TN', '9', '텐트동 9', TRUE, 120000, 8, '넓은 텐트형 공간으로 단체 모임에 적합')
ON CONFLICT (internal_code) DO UPDATE SET 
  category_code = EXCLUDED.category_code, 
  label = EXCLUDED.label, 
  display_name = EXCLUDED.display_name, 
  active = EXCLUDED.active,
  price = EXCLUDED.price,
  max_guests = EXCLUDED.max_guests,
  description = EXCLUDED.description;

-- VIP동 (1개)
INSERT INTO public.resource_catalog(internal_code, category_code, label, display_name, active, price, max_guests, description) VALUES 
('VP01', 'VP', '01', 'VIP동', TRUE, 300000, 12, '최고급 VIP 전용 공간으로 특별한 모임에 적합')
ON CONFLICT (internal_code) DO UPDATE SET 
  category_code = EXCLUDED.category_code, 
  label = EXCLUDED.label, 
  display_name = EXCLUDED.display_name, 
  active = EXCLUDED.active,
  price = EXCLUDED.price,
  max_guests = EXCLUDED.max_guests,
  description = EXCLUDED.description;

-- 야외 야장테이블 (4개)
INSERT INTO public.resource_catalog(internal_code, category_code, label, display_name, active, price, max_guests, description) VALUES 
('YT01', 'YT', 'W', '야외 야장테이블 W', TRUE, 100000, 6, '야외 바비큐 전용 야장 테이블'),
('YT02', 'YT', 'X', '야외 야장테이블 X', TRUE, 100000, 6, '야외 바비큐 전용 야장 테이블'),
('YT03', 'YT', 'Y', '야외 야장테이블 Y', TRUE, 100000, 6, '야외 바비큐 전용 야장 테이블'),
('YT04', 'YT', 'Z', '야외 야장테이블 Z', TRUE, 100000, 6, '야외 바비큐 전용 야장 테이블')
ON CONFLICT (internal_code) DO UPDATE SET 
  category_code = EXCLUDED.category_code, 
  label = EXCLUDED.label, 
  display_name = EXCLUDED.display_name, 
  active = EXCLUDED.active,
  price = EXCLUDED.price,
  max_guests = EXCLUDED.max_guests,
  description = EXCLUDED.description;

-- ============================================
-- SKU 카탈로그 데이터 입력 (모든 조합 생성)
-- ============================================

-- 프라이빗룸 SKU 생성
INSERT INTO public.sku_catalog(sku_code, internal_code, slot_id) VALUES 
('PR01-T1', 'PR01', 'T1'), ('PR01-T2', 'PR01', 'T2'), ('PR01-T3', 'PR01', 'T3'),
('PR02-T1', 'PR02', 'T1'), ('PR02-T2', 'PR02', 'T2'), ('PR02-T3', 'PR02', 'T3'),
('PR03-T1', 'PR03', 'T1'), ('PR03-T2', 'PR03', 'T2'), ('PR03-T3', 'PR03', 'T3'),
('PR04-T1', 'PR04', 'T1'), ('PR04-T2', 'PR04', 'T2'), ('PR04-T3', 'PR04', 'T3'),
('PR05-T1', 'PR05', 'T1'), ('PR05-T2', 'PR05', 'T2'), ('PR05-T3', 'PR05', 'T3')
ON CONFLICT (sku_code) DO NOTHING;

-- 소파테이블 SKU 생성
INSERT INTO public.sku_catalog(sku_code, internal_code, slot_id) VALUES 
('ST01-T1', 'ST01', 'T1'), ('ST01-T2', 'ST01', 'T2'), ('ST01-T3', 'ST01', 'T3'),
('ST02-T1', 'ST02', 'T1'), ('ST02-T2', 'ST02', 'T2'), ('ST02-T3', 'ST02', 'T3'),
('ST03-T1', 'ST03', 'T1'), ('ST03-T2', 'ST03', 'T2'), ('ST03-T3', 'ST03', 'T3'),
('ST04-T1', 'ST04', 'T1'), ('ST04-T2', 'ST04', 'T2'), ('ST04-T3', 'ST04', 'T3'),
('ST05-T1', 'ST05', 'T1'), ('ST05-T2', 'ST05', 'T2'), ('ST05-T3', 'ST05', 'T3'),
('ST06-T1', 'ST06', 'T1'), ('ST06-T2', 'ST06', 'T2'), ('ST06-T3', 'ST06', 'T3'),
('ST07-T1', 'ST07', 'T1'), ('ST07-T2', 'ST07', 'T2'), ('ST07-T3', 'ST07', 'T3')
ON CONFLICT (sku_code) DO NOTHING;

-- 텐트동 SKU 생성
INSERT INTO public.sku_catalog(sku_code, internal_code, slot_id) VALUES 
('TN01-T1', 'TN01', 'T1'), ('TN01-T2', 'TN01', 'T2'), ('TN01-T3', 'TN01', 'T3'),
('TN02-T1', 'TN02', 'T1'), ('TN02-T2', 'TN02', 'T2'), ('TN02-T3', 'TN02', 'T3'),
('TN03-T1', 'TN03', 'T1'), ('TN03-T2', 'TN03', 'T2'), ('TN03-T3', 'TN03', 'T3'),
('TN04-T1', 'TN04', 'T1'), ('TN04-T2', 'TN04', 'T2'), ('TN04-T3', 'TN04', 'T3'),
('TN05-T1', 'TN05', 'T1'), ('TN05-T2', 'TN05', 'T2'), ('TN05-T3', 'TN05', 'T3'),
('TN06-T1', 'TN06', 'T1'), ('TN06-T2', 'TN06', 'T2'), ('TN06-T3', 'TN06', 'T3'),
('TN07-T1', 'TN07', 'T1'), ('TN07-T2', 'TN07', 'T2'), ('TN07-T3', 'TN07', 'T3'),
('TN08-T1', 'TN08', 'T1'), ('TN08-T2', 'TN08', 'T2'), ('TN08-T3', 'TN08', 'T3'),
('TN09-T1', 'TN09', 'T1'), ('TN09-T2', 'TN09', 'T2'), ('TN09-T3', 'TN09', 'T3')
ON CONFLICT (sku_code) DO NOTHING;

-- VIP동 SKU 생성
INSERT INTO public.sku_catalog(sku_code, internal_code, slot_id) VALUES 
('VP01-T1', 'VP01', 'T1'), ('VP01-T2', 'VP01', 'T2'), ('VP01-T3', 'VP01', 'T3')
ON CONFLICT (sku_code) DO NOTHING;

-- 야장테이블 SKU 생성
INSERT INTO public.sku_catalog(sku_code, internal_code, slot_id) VALUES 
('YT01-T1', 'YT01', 'T1'), ('YT01-T2', 'YT01', 'T2'), ('YT01-T3', 'YT01', 'T3'),
('YT02-T1', 'YT02', 'T1'), ('YT02-T2', 'YT02', 'T2'), ('YT02-T3', 'YT02', 'T3'),
('YT03-T1', 'YT03', 'T1'), ('YT03-T2', 'YT03', 'T2'), ('YT03-T3', 'YT03', 'T3'),
('YT04-T1', 'YT04', 'T1'), ('YT04-T2', 'YT04', 'T2'), ('YT04-T3', 'YT04', 'T3')
ON CONFLICT (sku_code) DO NOTHING;

COMMIT;