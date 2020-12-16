-- Convert schema '/mnt/hgfs/meritcommons/var/sql/migrations/_source/deploy/3/001-auto.yml' to '/mnt/hgfs/meritcommons/var/sql/migrations/_source/deploy/4/001-auto.yml':;

;
BEGIN;

;
CREATE TABLE "meritcommons_stream_message_info" (
  "id" bigserial NOT NULL,
  "message" bigint NOT NULL,
  "meritcommons_user" integer NOT NULL,
  "info" text NOT NULL,
  "modify_time" integer NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "meritcommons_stream_message_info_idx_meritcommons_user" on "meritcommons_stream_message_info" ("meritcommons_user");
CREATE INDEX "meritcommons_stream_message_info_idx_message" on "meritcommons_stream_message_info" ("message");
CREATE INDEX "meritcommons_stream_message_info_message_user_idx" on "meritcommons_stream_message_info" ("message", "meritcommons_user");

;
ALTER TABLE "meritcommons_stream_message_info" ADD CONSTRAINT "meritcommons_stream_message_info_fk_meritcommons_user" FOREIGN KEY ("meritcommons_user")
  REFERENCES "meritcommons_user" ("id") DEFERRABLE;

;
ALTER TABLE "meritcommons_stream_message_info" ADD CONSTRAINT "meritcommons_stream_message_info_fk_message" FOREIGN KEY ("message")
  REFERENCES "meritcommons_stream_message" ("id") DEFERRABLE;

;

COMMIT;

