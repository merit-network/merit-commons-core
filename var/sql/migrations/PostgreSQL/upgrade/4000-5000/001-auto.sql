-- Convert schema '/usr/local/meritcommons/meritcommons/var/sql/migrations/_source/deploy/4000/001-auto.yml' to '/usr/local/meritcommons/meritcommons/var/sql/migrations/_source/deploy/5000/001-auto.yml':;

;
BEGIN;

;
CREATE TABLE "meritcommons_user_blockedentity" (
  "id" serial NOT NULL,
  "create_time" integer NOT NULL,
  "meritcommons_user" integer NOT NULL,
  "entity_type" character varying NOT NULL,
  "entity_id" character varying(64) NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "meritcommons_user_blockedentity_meritcommons_user_entity_id" UNIQUE ("meritcommons_user", "entity_id")
);
CREATE INDEX "meritcommons_user_blockedentity_idx_meritcommons_user" on "meritcommons_user_blockedentity" ("meritcommons_user");
CREATE INDEX "entity_id_idx" on "meritcommons_user_blockedentity" ("entity_id");

;
ALTER TABLE "meritcommons_user_blockedentity" ADD CONSTRAINT "meritcommons_user_blockedentity_fk_meritcommons_user" FOREIGN KEY ("meritcommons_user")
  REFERENCES "meritcommons_user" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE meritcommons_stream_message ADD COLUMN read_only integer DEFAULT 0;

;
ALTER TABLE meritcommons_user DROP CONSTRAINT meritcommons_user_fk_notification_inbox;

;
ALTER TABLE meritcommons_user DROP CONSTRAINT meritcommons_user_fk_personal_inbox;

;
ALTER TABLE meritcommons_user DROP CONSTRAINT meritcommons_user_fk_personal_outbox;

;

COMMIT;

