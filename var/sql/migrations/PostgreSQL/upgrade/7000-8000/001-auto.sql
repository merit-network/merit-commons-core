-- Convert schema '/usr/local/meritcommons/meritcommons/var/sql/migrations/_source/deploy/7000/001-auto.yml' to '/usr/local/meritcommons/meritcommons/var/sql/migrations/_source/deploy/8000/001-auto.yml':;

;
BEGIN;

;
CREATE TABLE "meritcommons_keyregistry" (
  "id" serial NOT NULL,
  "certificate" text NOT NULL,
  "thumbprint" character varying(255) NOT NULL,
  "purpose" character varying NOT NULL,
  "type" character varying NOT NULL,
  "status" character varying NOT NULL,
  "key_file" text NOT NULL,
  "key_length" integer NOT NULL,
  "expire_time" integer NOT NULL,
  "create_time" integer NOT NULL,
  "modify_time" integer NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "thumbprint" UNIQUE ("thumbprint")
);
CREATE INDEX "meritcommons_keyregistry_purpose_idx" on "meritcommons_keyregistry" ("purpose");
CREATE INDEX "meritcommons_keyregistry_type_idx" on "meritcommons_keyregistry" ("type");
CREATE INDEX "meritcommons_keyregistry_status_idx" on "meritcommons_keyregistry" ("status");

;
ALTER TABLE meritcommons_user_identityuser DROP CONSTRAINT meritcommons_user_identityuser_fk_identity;

;
ALTER TABLE meritcommons_user_identityuser ADD CONSTRAINT meritcommons_user_identityuser_fk_identity FOREIGN KEY (identity)
  REFERENCES meritcommons_user_identity (id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE meritcommons_user_roleuser DROP CONSTRAINT meritcommons_user_roleuser_fk_role;

;
ALTER TABLE meritcommons_user_roleuser ADD CONSTRAINT meritcommons_user_roleuser_fk_role FOREIGN KEY (role)
  REFERENCES meritcommons_user_role (id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;

COMMIT;

