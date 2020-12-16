-- Convert schema '/usr/local/meritcommons/meritcommons/var/sql/migrations/_source/deploy/9000/001-auto.yml' to '/usr/local/meritcommons/meritcommons/var/sql/migrations/_source/deploy/8000/001-auto.yml':;

;
BEGIN;

;
DROP INDEX txn_id_idx;

;
ALTER TABLE meritcommons_user_meritcommonscointransaction DROP COLUMN transaction_id;

;
ALTER TABLE meritcommons_user_meritcommonscointransaction DROP COLUMN related_transaction;

;
ALTER TABLE meritcommons_user_meritcommonscointransaction DROP COLUMN second_party;

;
ALTER TABLE meritcommons_user_meritcommonscointransaction ADD COLUMN unique_id character varying(64) NOT NULL;

;
ALTER TABLE meritcommons_user_meritcommonscointransaction ADD CONSTRAINT meritcommons_user_meritcommonscointransaction_fk_meritcommons_user FOREIGN KEY (meritcommons_user)
  REFERENCES meritcommons_user (id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;

COMMIT;

