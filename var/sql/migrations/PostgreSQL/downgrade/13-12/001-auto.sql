-- Convert schema '/mnt/hgfs/meritcommons-trunk/var/sql/migrations/_source/deploy/13/001-auto.yml' to '/mnt/hgfs/meritcommons-trunk/var/sql/migrations/_source/deploy/12/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_user DROP CONSTRAINT meritcommons_user_public_key_fingerprint;

;
DROP INDEX public_key_fingerprint_idx;

;
ALTER TABLE meritcommons_user DROP COLUMN public_key_fingerprint;

;

COMMIT;

