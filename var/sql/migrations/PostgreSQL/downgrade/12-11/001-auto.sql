-- Convert schema '/mnt/hgfs/meritcommons-trunk/var/sql/migrations/_source/deploy/12/001-auto.yml' to '/mnt/hgfs/meritcommons-trunk/var/sql/migrations/_source/deploy/11/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_user DROP COLUMN email_address;

;
ALTER TABLE meritcommons_user DROP COLUMN organization;

;
ALTER TABLE meritcommons_user DROP COLUMN title;

;
ALTER TABLE meritcommons_user DROP COLUMN public_key;

;
ALTER TABLE meritcommons_user DROP COLUMN secret_key;

;
ALTER TABLE meritcommons_user ADD COLUMN enc_pub_key character varying(255);

;
ALTER TABLE meritcommons_user ADD COLUMN enc_priv_key character varying(255);

;
ALTER TABLE meritcommons_user ADD COLUMN sign_pub_key character varying(255);

;
ALTER TABLE meritcommons_user ADD COLUMN sign_priv_key character varying(255);

;

COMMIT;

