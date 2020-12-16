-- Convert schema '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/25/001-auto.yml' to '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/26/001-auto.yml':;

;
BEGIN;

;
CREATE TABLE "meritcommons_stream_invite" (
  "id" serial NOT NULL,
  "inviter" integer NOT NULL,
  "invitee" integer NOT NULL,
  "stream" integer NOT NULL,
  "create_time" integer NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "meritcommons_stream_invite_inviter_invitee_stream" UNIQUE ("inviter", "invitee", "stream")
);
CREATE INDEX "meritcommons_stream_invite_idx_invitee" on "meritcommons_stream_invite" ("invitee");
CREATE INDEX "meritcommons_stream_invite_idx_inviter" on "meritcommons_stream_invite" ("inviter");
CREATE INDEX "meritcommons_stream_invite_idx_stream" on "meritcommons_stream_invite" ("stream");

;
ALTER TABLE "meritcommons_stream_invite" ADD CONSTRAINT "meritcommons_stream_invite_fk_invitee" FOREIGN KEY ("invitee")
  REFERENCES "meritcommons_user" ("id") DEFERRABLE;

;
ALTER TABLE "meritcommons_stream_invite" ADD CONSTRAINT "meritcommons_stream_invite_fk_inviter" FOREIGN KEY ("inviter")
  REFERENCES "meritcommons_user" ("id") DEFERRABLE;

;
ALTER TABLE "meritcommons_stream_invite" ADD CONSTRAINT "meritcommons_stream_invite_fk_stream" FOREIGN KEY ("stream")
  REFERENCES "meritcommons_stream" ("id") DEFERRABLE;

;
ALTER TABLE meritcommons_stream ADD COLUMN subscriber_count integer DEFAULT 0 NOT NULL;

;
ALTER TABLE meritcommons_stream ADD COLUMN author_count integer DEFAULT 0 NOT NULL;

;
ALTER TABLE meritcommons_stream ADD COLUMN moderator_count integer DEFAULT 0 NOT NULL;

;
ALTER TABLE meritcommons_stream ADD COLUMN members_can_invite integer DEFAULT 0 NOT NULL;

;

update meritcommons_stream set members_can_invite = 0;

;

COMMIT;

