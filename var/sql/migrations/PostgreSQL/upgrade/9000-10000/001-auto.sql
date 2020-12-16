-- Convert schema '/usr/local/meritcommons/meritcommons/var/sql/migrations/_source/deploy/9000/001-auto.yml' to '/usr/local/meritcommons/meritcommons/var/sql/migrations/_source/deploy/10000/001-auto.yml':;

;
BEGIN;

;
CREATE TABLE "meritcommons_stream_changelog" (
  "id" serial NOT NULL,
  "actor" integer NOT NULL,
  "create_time" integer NOT NULL,
  "stream" integer NOT NULL,
  "undo_id" character varying(64),
  "undo_data" text,
  "description" text,
  "title" character varying(255)
);
CREATE INDEX "stream_changelog_undo_id_idx" on "meritcommons_stream_changelog" ("undo_id");
CREATE INDEX "stream_changelog_create_time_idx" on "meritcommons_stream_changelog" ("create_time");
CREATE INDEX "stream_changelog_stream_idx" on "meritcommons_stream_changelog" ("stream");

;
CREATE TABLE "meritcommons_stream_message_changelog" (
  "id" serial NOT NULL,
  "actor" integer NOT NULL,
  "create_time" integer NOT NULL,
  "message" integer NOT NULL,
  "undo_id" character varying(64),
  "undo_data" text,
  "description" text,
  "title" character varying(255)
);
CREATE INDEX "stream_message_changelog_undo_id_idx" on "meritcommons_stream_message_changelog" ("undo_id");
CREATE INDEX "stream_message_changelog_create_time_idx" on "meritcommons_stream_message_changelog" ("create_time");
CREATE INDEX "stream_message_changelog_message_idx" on "meritcommons_stream_message_changelog" ("message");

;
CREATE TABLE "meritcommons_user_changelog" (
  "id" serial NOT NULL,
  "actor" integer NOT NULL,
  "create_time" integer NOT NULL,
  "meritcommons_user" integer NOT NULL,
  "undo_id" character varying(64),
  "undo_data" text,
  "description" text,
  "title" character varying(255)
);
CREATE INDEX "user_changelog_undo_id_idx" on "meritcommons_user_changelog" ("undo_id");
CREATE INDEX "user_changelog_create_time_idx" on "meritcommons_user_changelog" ("create_time");
CREATE INDEX "user_changelog_meritcommons_user_idx" on "meritcommons_user_changelog" ("meritcommons_user");

;
DROP TABLE meritcommons_changelog CASCADE;

;

COMMIT;

