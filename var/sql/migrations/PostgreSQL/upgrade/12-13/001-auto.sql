-- Convert schema '/mnt/hgfs/meritcommons-trunk/var/sql/migrations/_source/deploy/12/001-auto.yml' to '/mnt/hgfs/meritcommons-trunk/var/sql/migrations/_source/deploy/13/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_user ADD COLUMN public_key_fingerprint character varying;

;
CREATE INDEX public_key_fingerprint_idx on meritcommons_user (public_key_fingerprint);

;
ALTER TABLE meritcommons_user ADD CONSTRAINT meritcommons_user_public_key_fingerprint UNIQUE (public_key_fingerprint);

;

COMMIT;

