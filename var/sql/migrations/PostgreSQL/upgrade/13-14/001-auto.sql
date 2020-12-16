-- Convert schema '/mnt/hgfs/meritcommons/var/sql/migrations/_source/deploy/13/001-auto.yml' to '/mnt/hgfs/meritcommons/var/sql/migrations/_source/deploy/14/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_stream ADD COLUMN public_key text;

;
ALTER TABLE meritcommons_stream ADD COLUMN secret_key text;

;
CREATE INDEX email_address_idx on meritcommons_user (email_address);

;

COMMIT;

