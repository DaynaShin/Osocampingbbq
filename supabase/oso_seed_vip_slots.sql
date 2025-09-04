-- OSO Camping BBQ - Catalog schema + seed (VIP uses T1/T2/T3 slots as backend locks)
BEGIN;

CREATE TABLE IF NOT EXISTS resource_catalog (
  internal_code TEXT PRIMARY KEY,
  category_code TEXT NOT NULL,
  label TEXT,
  display_name TEXT NOT NULL,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  CHECK (internal_code ~ '^[A-Z]{2}[0-9]{2}$')
);


CREATE TABLE IF NOT EXISTS time_slot_catalog (
  slot_id TEXT PRIMARY KEY,
  part_name TEXT NOT NULL,
  slot_name TEXT NOT NULL,
  start_local TIME NOT NULL,
  end_local TIME NOT NULL
);


CREATE TABLE IF NOT EXISTS sku_catalog (
  sku_code TEXT PRIMARY KEY,
  internal_code TEXT NOT NULL REFERENCES resource_catalog(internal_code) ON DELETE CASCADE,
  slot_id TEXT NOT NULL REFERENCES time_slot_catalog(slot_id),
  CHECK (sku_code ~ '^[A-Z]{2}[0-9]{2}-T[123]$')
);

INSERT INTO time_slot_catalog(slot_id, part_name, slot_name, start_local, end_local) VALUES ('T1', '1부', '타임1', '10:00', '13:00') ON CONFLICT (slot_id) DO UPDATE SET part_name=EXCLUDED.part_name, slot_name=EXCLUDED.slot_name, start_local=EXCLUDED.start_local, end_local=EXCLUDED.end_local;
INSERT INTO time_slot_catalog(slot_id, part_name, slot_name, start_local, end_local) VALUES ('T2', '2부', '타임2', '14:00', '17:00') ON CONFLICT (slot_id) DO UPDATE SET part_name=EXCLUDED.part_name, slot_name=EXCLUDED.slot_name, start_local=EXCLUDED.start_local, end_local=EXCLUDED.end_local;
INSERT INTO time_slot_catalog(slot_id, part_name, slot_name, start_local, end_local) VALUES ('T3', '3부', '타임3', '18:00', '21:00') ON CONFLICT (slot_id) DO UPDATE SET part_name=EXCLUDED.part_name, slot_name=EXCLUDED.slot_name, start_local=EXCLUDED.start_local, end_local=EXCLUDED.end_local;
INSERT INTO resource_catalog(internal_code, category_code, label, display_name, active) VALUES ('PR01', 'PR', '가', '프라이빗룸 가', TRUE) ON CONFLICT (internal_code) DO UPDATE SET category_code=EXCLUDED.category_code, label=EXCLUDED.label, display_name=EXCLUDED.display_name, active=EXCLUDED.active;
INSERT INTO resource_catalog(internal_code, category_code, label, display_name, active) VALUES ('PR02', 'PR', '나', '프라이빗룸 나', TRUE) ON CONFLICT (internal_code) DO UPDATE SET category_code=EXCLUDED.category_code, label=EXCLUDED.label, display_name=EXCLUDED.display_name, active=EXCLUDED.active;
INSERT INTO resource_catalog(internal_code, category_code, label, display_name, active) VALUES ('PR03', 'PR', '다', '프라이빗룸 다', TRUE) ON CONFLICT (internal_code) DO UPDATE SET category_code=EXCLUDED.category_code, label=EXCLUDED.label, display_name=EXCLUDED.display_name, active=EXCLUDED.active;
INSERT INTO resource_catalog(internal_code, category_code, label, display_name, active) VALUES ('PR04', 'PR', '라', '프라이빗룸 라', TRUE) ON CONFLICT (internal_code) DO UPDATE SET category_code=EXCLUDED.category_code, label=EXCLUDED.label, display_name=EXCLUDED.display_name, active=EXCLUDED.active;
INSERT INTO resource_catalog(internal_code, category_code, label, display_name, active) VALUES ('PR05', 'PR', '마', '프라이빗룸 마', TRUE) ON CONFLICT (internal_code) DO UPDATE SET category_code=EXCLUDED.category_code, label=EXCLUDED.label, display_name=EXCLUDED.display_name, active=EXCLUDED.active;
INSERT INTO resource_catalog(internal_code, category_code, label, display_name, active) VALUES ('ST01', 'ST', 'A', '야외 소파테이블 A', TRUE) ON CONFLICT (internal_code) DO UPDATE SET category_code=EXCLUDED.category_code, label=EXCLUDED.label, display_name=EXCLUDED.display_name, active=EXCLUDED.active;
INSERT INTO resource_catalog(internal_code, category_code, label, display_name, active) VALUES ('ST02', 'ST', 'B', '야외 소파테이블 B', TRUE) ON CONFLICT (internal_code) DO UPDATE SET category_code=EXCLUDED.category_code, label=EXCLUDED.label, display_name=EXCLUDED.display_name, active=EXCLUDED.active;
INSERT INTO resource_catalog(internal_code, category_code, label, display_name, active) VALUES ('ST03', 'ST', 'C', '야외 소파테이블 C', TRUE) ON CONFLICT (internal_code) DO UPDATE SET category_code=EXCLUDED.category_code, label=EXCLUDED.label, display_name=EXCLUDED.display_name, active=EXCLUDED.active;
INSERT INTO resource_catalog(internal_code, category_code, label, display_name, active) VALUES ('ST04', 'ST', 'D', '야외 소파테이블 D', TRUE) ON CONFLICT (internal_code) DO UPDATE SET category_code=EXCLUDED.category_code, label=EXCLUDED.label, display_name=EXCLUDED.display_name, active=EXCLUDED.active;
INSERT INTO resource_catalog(internal_code, category_code, label, display_name, active) VALUES ('ST05', 'ST', 'E', '야외 소파테이블 E', TRUE) ON CONFLICT (internal_code) DO UPDATE SET category_code=EXCLUDED.category_code, label=EXCLUDED.label, display_name=EXCLUDED.display_name, active=EXCLUDED.active;
INSERT INTO resource_catalog(internal_code, category_code, label, display_name, active) VALUES ('ST06', 'ST', 'F', '야외 소파테이블 F', TRUE) ON CONFLICT (internal_code) DO UPDATE SET category_code=EXCLUDED.category_code, label=EXCLUDED.label, display_name=EXCLUDED.display_name, active=EXCLUDED.active;
INSERT INTO resource_catalog(internal_code, category_code, label, display_name, active) VALUES ('ST07', 'ST', 'G', '야외 소파테이블 G', TRUE) ON CONFLICT (internal_code) DO UPDATE SET category_code=EXCLUDED.category_code, label=EXCLUDED.label, display_name=EXCLUDED.display_name, active=EXCLUDED.active;
INSERT INTO resource_catalog(internal_code, category_code, label, display_name, active) VALUES ('TN01', 'TN', '1', '텐트동 1', TRUE) ON CONFLICT (internal_code) DO UPDATE SET category_code=EXCLUDED.category_code, label=EXCLUDED.label, display_name=EXCLUDED.display_name, active=EXCLUDED.active;
INSERT INTO resource_catalog(internal_code, category_code, label, display_name, active) VALUES ('TN02', 'TN', '2', '텐트동 2', TRUE) ON CONFLICT (internal_code) DO UPDATE SET category_code=EXCLUDED.category_code, label=EXCLUDED.label, display_name=EXCLUDED.display_name, active=EXCLUDED.active;
INSERT INTO resource_catalog(internal_code, category_code, label, display_name, active) VALUES ('TN03', 'TN', '3', '텐트동 3', TRUE) ON CONFLICT (internal_code) DO UPDATE SET category_code=EXCLUDED.category_code, label=EXCLUDED.label, display_name=EXCLUDED.display_name, active=EXCLUDED.active;
INSERT INTO resource_catalog(internal_code, category_code, label, display_name, active) VALUES ('TN04', 'TN', '4', '텐트동 4', TRUE) ON CONFLICT (internal_code) DO UPDATE SET category_code=EXCLUDED.category_code, label=EXCLUDED.label, display_name=EXCLUDED.display_name, active=EXCLUDED.active;
INSERT INTO resource_catalog(internal_code, category_code, label, display_name, active) VALUES ('TN05', 'TN', '5', '텐트동 5', TRUE) ON CONFLICT (internal_code) DO UPDATE SET category_code=EXCLUDED.category_code, label=EXCLUDED.label, display_name=EXCLUDED.display_name, active=EXCLUDED.active;
INSERT INTO resource_catalog(internal_code, category_code, label, display_name, active) VALUES ('TN06', 'TN', '6', '텐트동 6', TRUE) ON CONFLICT (internal_code) DO UPDATE SET category_code=EXCLUDED.category_code, label=EXCLUDED.label, display_name=EXCLUDED.display_name, active=EXCLUDED.active;
INSERT INTO resource_catalog(internal_code, category_code, label, display_name, active) VALUES ('TN07', 'TN', '7', '텐트동 7', TRUE) ON CONFLICT (internal_code) DO UPDATE SET category_code=EXCLUDED.category_code, label=EXCLUDED.label, display_name=EXCLUDED.display_name, active=EXCLUDED.active;
INSERT INTO resource_catalog(internal_code, category_code, label, display_name, active) VALUES ('TN08', 'TN', '8', '텐트동 8', TRUE) ON CONFLICT (internal_code) DO UPDATE SET category_code=EXCLUDED.category_code, label=EXCLUDED.label, display_name=EXCLUDED.display_name, active=EXCLUDED.active;
INSERT INTO resource_catalog(internal_code, category_code, label, display_name, active) VALUES ('TN09', 'TN', '9', '텐트동 9', TRUE) ON CONFLICT (internal_code) DO UPDATE SET category_code=EXCLUDED.category_code, label=EXCLUDED.label, display_name=EXCLUDED.display_name, active=EXCLUDED.active;
INSERT INTO resource_catalog(internal_code, category_code, label, display_name, active) VALUES ('VP01', 'VP', '01', 'VIP동', TRUE) ON CONFLICT (internal_code) DO UPDATE SET category_code=EXCLUDED.category_code, label=EXCLUDED.label, display_name=EXCLUDED.display_name, active=EXCLUDED.active;
INSERT INTO resource_catalog(internal_code, category_code, label, display_name, active) VALUES ('YT01', 'YT', 'W', '야외 야장테이블 W', TRUE) ON CONFLICT (internal_code) DO UPDATE SET category_code=EXCLUDED.category_code, label=EXCLUDED.label, display_name=EXCLUDED.display_name, active=EXCLUDED.active;
INSERT INTO resource_catalog(internal_code, category_code, label, display_name, active) VALUES ('YT02', 'YT', 'X', '야외 야장테이블 X', TRUE) ON CONFLICT (internal_code) DO UPDATE SET category_code=EXCLUDED.category_code, label=EXCLUDED.label, display_name=EXCLUDED.display_name, active=EXCLUDED.active;
INSERT INTO resource_catalog(internal_code, category_code, label, display_name, active) VALUES ('YT03', 'YT', 'Y', '야외 야장테이블 Y', TRUE) ON CONFLICT (internal_code) DO UPDATE SET category_code=EXCLUDED.category_code, label=EXCLUDED.label, display_name=EXCLUDED.display_name, active=EXCLUDED.active;
INSERT INTO resource_catalog(internal_code, category_code, label, display_name, active) VALUES ('YT04', 'YT', 'Z', '야외 야장테이블 Z', TRUE) ON CONFLICT (internal_code) DO UPDATE SET category_code=EXCLUDED.category_code, label=EXCLUDED.label, display_name=EXCLUDED.display_name, active=EXCLUDED.active;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('PR01-T1', 'PR01', 'T1') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('PR01-T2', 'PR01', 'T2') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('PR01-T3', 'PR01', 'T3') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('PR02-T1', 'PR02', 'T1') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('PR02-T2', 'PR02', 'T2') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('PR02-T3', 'PR02', 'T3') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('PR03-T1', 'PR03', 'T1') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('PR03-T2', 'PR03', 'T2') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('PR03-T3', 'PR03', 'T3') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('PR04-T1', 'PR04', 'T1') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('PR04-T2', 'PR04', 'T2') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('PR04-T3', 'PR04', 'T3') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('PR05-T1', 'PR05', 'T1') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('PR05-T2', 'PR05', 'T2') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('PR05-T3', 'PR05', 'T3') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('ST01-T1', 'ST01', 'T1') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('ST01-T2', 'ST01', 'T2') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('ST01-T3', 'ST01', 'T3') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('ST02-T1', 'ST02', 'T1') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('ST02-T2', 'ST02', 'T2') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('ST02-T3', 'ST02', 'T3') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('ST03-T1', 'ST03', 'T1') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('ST03-T2', 'ST03', 'T2') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('ST03-T3', 'ST03', 'T3') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('ST04-T1', 'ST04', 'T1') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('ST04-T2', 'ST04', 'T2') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('ST04-T3', 'ST04', 'T3') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('ST05-T1', 'ST05', 'T1') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('ST05-T2', 'ST05', 'T2') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('ST05-T3', 'ST05', 'T3') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('ST06-T1', 'ST06', 'T1') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('ST06-T2', 'ST06', 'T2') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('ST06-T3', 'ST06', 'T3') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('ST07-T1', 'ST07', 'T1') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('ST07-T2', 'ST07', 'T2') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('ST07-T3', 'ST07', 'T3') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('TN01-T1', 'TN01', 'T1') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('TN01-T2', 'TN01', 'T2') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('TN01-T3', 'TN01', 'T3') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('TN02-T1', 'TN02', 'T1') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('TN02-T2', 'TN02', 'T2') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('TN02-T3', 'TN02', 'T3') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('TN03-T1', 'TN03', 'T1') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('TN03-T2', 'TN03', 'T2') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('TN03-T3', 'TN03', 'T3') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('TN04-T1', 'TN04', 'T1') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('TN04-T2', 'TN04', 'T2') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('TN04-T3', 'TN04', 'T3') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('TN05-T1', 'TN05', 'T1') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('TN05-T2', 'TN05', 'T2') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('TN05-T3', 'TN05', 'T3') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('TN06-T1', 'TN06', 'T1') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('TN06-T2', 'TN06', 'T2') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('TN06-T3', 'TN06', 'T3') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('TN07-T1', 'TN07', 'T1') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('TN07-T2', 'TN07', 'T2') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('TN07-T3', 'TN07', 'T3') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('TN08-T1', 'TN08', 'T1') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('TN08-T2', 'TN08', 'T2') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('TN08-T3', 'TN08', 'T3') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('TN09-T1', 'TN09', 'T1') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('TN09-T2', 'TN09', 'T2') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('TN09-T3', 'TN09', 'T3') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('VP01-T1', 'VP01', 'T1') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('VP01-T2', 'VP01', 'T2') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('VP01-T3', 'VP01', 'T3') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('YT01-T1', 'YT01', 'T1') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('YT01-T2', 'YT01', 'T2') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('YT01-T3', 'YT01', 'T3') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('YT02-T1', 'YT02', 'T1') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('YT02-T2', 'YT02', 'T2') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('YT02-T3', 'YT02', 'T3') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('YT03-T1', 'YT03', 'T1') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('YT03-T2', 'YT03', 'T2') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('YT03-T3', 'YT03', 'T3') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('YT04-T1', 'YT04', 'T1') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('YT04-T2', 'YT04', 'T2') ON CONFLICT (sku_code) DO NOTHING;
INSERT INTO sku_catalog(sku_code, internal_code, slot_id) VALUES ('YT04-T3', 'YT04', 'T3') ON CONFLICT (sku_code) DO NOTHING;
COMMIT;