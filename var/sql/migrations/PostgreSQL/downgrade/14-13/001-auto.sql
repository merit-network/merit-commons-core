-- Convert schema '/mnt/hgfs/meritcommons/var/sql/migrations/_source/deploy/14/001-auto.yml' to '/mnt/hgfs/meritcommons/var/sql/migrations/_source/deploy/13/001-auto.yml':;

;
BEGIN;

;
DROP INDEX email_address_idx;

;
ALTER TABLE meritcommons_stream DROP COLUMN public_key;

;
ALTER TABLE meritcommons_stream DROP COLUMN secret_key;

;

COMMIT;

