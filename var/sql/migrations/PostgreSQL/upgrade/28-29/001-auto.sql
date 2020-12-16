-- Convert schema '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/28/001-auto.yml' to '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/29/001-auto.yml':;

;
BEGIN;

;
CREATE TABLE "meritcommons_changelog" (
  "id" serial NOT NULL,
  "actor" integer NOT NULL,
  "create_time" integer NOT NULL,
  "entity_changed" character varying(64) NOT NULL,
  "entity_type" character varying NOT NULL,
  "undo_id" character varying(64),
  "undo_data" text,
  "description" text,
  "title" character varying(255)
);
CREATE INDEX "meritcommons_changelog_idx_actor" on "meritcommons_changelog" ("actor");
CREATE INDEX "changelog_undo_id_idx" on "meritcommons_changelog" ("undo_id");
CREATE INDEX "changelog_create_time_idx" on "meritcommons_changelog" ("create_time");

;
ALTER TABLE "meritcommons_changelog" ADD CONSTRAINT "meritcommons_changelog_fk_actor" FOREIGN KEY ("actor")
  REFERENCES "meritcommons_user" ("id") DEFERRABLE;

;
CREATE INDEX meritcommons_stream_messagestream_idx_stream_message on meritcommons_stream_messagestream (message, stream);

;

COMMIT;

