-- Convert schema '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/1000/001-auto.yml' to '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/35/001-auto.yml':;

;
BEGIN;

;
CREATE TABLE "ap_casserver_ticket" (
  "id" serial NOT NULL,
  "meritcommons_user" integer NOT NULL,
  "ticket_id" character varying(255) NOT NULL,
  "service" text NOT NULL,
  "pgt_url" text,
  "issued_by_ticket" integer,
  "consumed" integer NOT NULL,
  "renew" integer NOT NULL,
  "issue_time" integer NOT NULL,
  "create_time" integer NOT NULL,
  "modify_time" integer NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "ap_casserver_ticket_idx_meritcommons_user" on "ap_casserver_ticket" ("meritcommons_user");
CREATE INDEX "ap_casserver_ticket_idx_issued_by_ticket" on "ap_casserver_ticket" ("issued_by_ticket");
CREATE INDEX "ap_casserver_ticket_ticket_id_idx" on "ap_casserver_ticket" ("ticket_id");
CREATE INDEX "ap_casserver_ticket_user_idx" on "ap_casserver_ticket" ("meritcommons_user");
CREATE INDEX "ap_casserver_ticket_create_time_idx" on "ap_casserver_ticket" ("create_time");

;
ALTER TABLE "ap_casserver_ticket" ADD CONSTRAINT "ap_casserver_ticket_fk_meritcommons_user" FOREIGN KEY ("meritcommons_user")
  REFERENCES "meritcommons_user" ("id") DEFERRABLE;

;
ALTER TABLE "ap_casserver_ticket" ADD CONSTRAINT "ap_casserver_ticket_fk_issued_by_ticket" FOREIGN KEY ("issued_by_ticket")
  REFERENCES "ap_casserver_ticket" ("id") DEFERRABLE;

;
ALTER TABLE meritcommons_stream_invite DROP CONSTRAINT meritcommons_stream_invite_fk_invitee;

;
ALTER TABLE meritcommons_stream_invite DROP CONSTRAINT meritcommons_stream_invite_fk_stream;

;
ALTER TABLE meritcommons_stream_invite ADD CONSTRAINT meritcommons_stream_invite_fk_invitee FOREIGN KEY (invitee)
  REFERENCES meritcommons_user (id) DEFERRABLE;

;
ALTER TABLE meritcommons_stream_invite ADD CONSTRAINT meritcommons_stream_invite_fk_stream FOREIGN KEY (stream)
  REFERENCES meritcommons_stream (id) DEFERRABLE;

;

COMMIT;

