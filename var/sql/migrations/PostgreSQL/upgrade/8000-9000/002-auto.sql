-- Convert schema '/usr/local/meritcommons/meritcommons/var/sql/migrations/_source/deploy/8000/001-auto.yml' to '/usr/local/meritcommons/meritcommons/var/sql/migrations/_source/deploy/9000/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_user_meritcommonscointransaction DROP CONSTRAINT meritcommons_user_meritcommonscointransaction_fk_meritcommons_user;

;
ALTER TABLE meritcommons_user_meritcommonscointransaction DROP COLUMN unique_id;

;
ALTER TABLE meritcommons_user_meritcommonscointransaction ADD COLUMN transaction_id character varying(64) DEFAULT '00000000-0000-0000-DEAD-BEEFDEADBEEF' NOT NULL;

;
ALTER TABLE meritcommons_user_meritcommonscointransaction ADD COLUMN related_transaction integer;

;
ALTER TABLE meritcommons_user_meritcommonscointransaction ADD COLUMN second_party integer;

;
CREATE INDEX txn_id_idx on meritcommons_user_meritcommonscointransaction (transaction_id);

;

COMMIT;

