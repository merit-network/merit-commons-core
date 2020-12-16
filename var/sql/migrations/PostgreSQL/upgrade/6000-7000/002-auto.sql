-- Convert schema '/usr/local/meritcommons/meritcommons/var/sql/migrations/_source/deploy/6000/001-auto.yml' to '/usr/local/meritcommons/meritcommons/var/sql/migrations/_source/deploy/7000/001-auto.yml':;

;
BEGIN;

;
CREATE TABLE "meritcommons_user_meritcommonscoinrequest" (
  "id" serial NOT NULL,
  "create_time" integer NOT NULL,
  "modify_time" integer NOT NULL,
  "amount_requested" real NOT NULL,
  "reason" text NOT NULL,
  "approved" integer DEFAULT 0 NOT NULL,
  "updated_by" integer NOT NULL,
  "requested_by" integer NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "meritcommons_user_meritcommonscoinrequest_idx_requested_by" on "meritcommons_user_meritcommonscoinrequest" ("requested_by");
CREATE INDEX "meritcommons_user_meritcommonscoinrequest_idx_updated_by" on "meritcommons_user_meritcommonscoinrequest" ("updated_by");

;
CREATE TABLE "meritcommons_user_identityuser" (
  "id" serial NOT NULL,
  "meritcommons_user" integer,
  "identity" integer,
  PRIMARY KEY ("id"),
  CONSTRAINT "user_identityuser" UNIQUE ("meritcommons_user", "identity")
);
CREATE INDEX "meritcommons_user_identityuser_idx_meritcommons_user" on "meritcommons_user_identityuser" ("meritcommons_user");
CREATE INDEX "meritcommons_user_identityuser_idx_identity" on "meritcommons_user_identityuser" ("identity");

;
CREATE TABLE "meritcommons_user_roleuser" (
  "id" serial NOT NULL,
  "meritcommons_user" integer,
  "role" integer,
  PRIMARY KEY ("id"),
  CONSTRAINT "user_roleuser" UNIQUE ("meritcommons_user", "role")
);
CREATE INDEX "meritcommons_user_roleuser_idx_meritcommons_user" on "meritcommons_user_roleuser" ("meritcommons_user");
CREATE INDEX "meritcommons_user_roleuser_idx_role" on "meritcommons_user_roleuser" ("role");

;
ALTER TABLE "meritcommons_user_meritcommonscoinrequest" ADD CONSTRAINT "meritcommons_user_meritcommonscoinrequest_fk_requested_by" FOREIGN KEY ("requested_by")
  REFERENCES "meritcommons_user" ("id") DEFERRABLE;

;
ALTER TABLE "meritcommons_user_meritcommonscoinrequest" ADD CONSTRAINT "meritcommons_user_meritcommonscoinrequest_fk_updated_by" FOREIGN KEY ("updated_by")
  REFERENCES "meritcommons_user" ("id") DEFERRABLE;

;
ALTER TABLE "meritcommons_user_identityuser" ADD CONSTRAINT "meritcommons_user_identityuser_fk_meritcommons_user" FOREIGN KEY ("meritcommons_user")
  REFERENCES "meritcommons_user" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_user_identityuser" ADD CONSTRAINT "meritcommons_user_identityuser_fk_identity" FOREIGN KEY ("identity")
  REFERENCES "meritcommons_user_identity" ("id") DEFERRABLE;

;
ALTER TABLE "meritcommons_user_roleuser" ADD CONSTRAINT "meritcommons_user_roleuser_fk_meritcommons_user" FOREIGN KEY ("meritcommons_user")
  REFERENCES "meritcommons_user" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_user_roleuser" ADD CONSTRAINT "meritcommons_user_roleuser_fk_role" FOREIGN KEY ("role")
  REFERENCES "meritcommons_user_role" ("id") DEFERRABLE;

;
ALTER TABLE meritcommons_link ADD COLUMN role_policy character varying DEFAULT 'any' NOT NULL;

;
DROP TABLE meritcommons_user_tag CASCADE;

;
DROP TABLE meritcommons_user_group CASCADE;

;
DROP TABLE meritcommons_user_assignment CASCADE;

;

COMMIT;

