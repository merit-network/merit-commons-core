-- Convert schema '/mnt/hgfs/meritcommons-trunk/var/sql/migrations/_source/deploy/8/001-auto.yml' to '/mnt/hgfs/meritcommons-trunk/var/sql/migrations/_source/deploy/7/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_link_click DROP COLUMN counter;

;

COMMIT;

