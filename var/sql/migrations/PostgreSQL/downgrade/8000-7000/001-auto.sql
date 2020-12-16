-- Convert schema '/usr/local/meritcommons/meritcommons/var/sql/migrations/_source/deploy/8000/001-auto.yml' to '/usr/local/meritcommons/meritcommons/var/sql/migrations/_source/deploy/7000/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_user_identityuser DROP CONSTRAINT meritcommons_user_identityuser_fk_identity;

;
ALTER TABLE meritcommons_user_identityuser ADD CONSTRAINT meritcommons_user_identityuser_fk_identity FOREIGN KEY (identity)
  REFERENCES meritcommons_user_identity (id) DEFERRABLE;

;
ALTER TABLE meritcommons_user_roleuser DROP CONSTRAINT meritcommons_user_roleuser_fk_role;

;
ALTER TABLE meritcommons_user_roleuser ADD CONSTRAINT meritcommons_user_roleuser_fk_role FOREIGN KEY (role)
  REFERENCES meritcommons_user_role (id) DEFERRABLE;

;
DROP TABLE meritcommons_keyregistry CASCADE;

;

COMMIT;

