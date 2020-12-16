-- Convert schema '/mnt/hgfs/meritcommons-trunk/var/sql/migrations/_source/deploy/11/001-auto.yml' to '/mnt/hgfs/meritcommons-trunk/var/sql/migrations/_source/deploy/12/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_user DROP COLUMN enc_pub_key;

;
ALTER TABLE meritcommons_user DROP COLUMN enc_priv_key;

;
ALTER TABLE meritcommons_user DROP COLUMN sign_pub_key;

;
ALTER TABLE meritcommons_user DROP COLUMN sign_priv_key;

;
ALTER TABLE meritcommons_user ADD COLUMN email_address character varying(255);

;
ALTER TABLE meritcommons_user ADD COLUMN organization character varying(255);

;
ALTER TABLE meritcommons_user ADD COLUMN title character varying(255);

;
ALTER TABLE meritcommons_user ADD COLUMN public_key text;

;
ALTER TABLE meritcommons_user ADD COLUMN secret_key text;

;

COMMIT;

