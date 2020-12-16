-- Convert schema '/usr/local/meritcommons/meritcommons/var/sql/migrations/_source/deploy/7000/001-auto.yml' to '/usr/local/meritcommons/meritcommons/var/sql/migrations/_source/deploy/6000/001-auto.yml':;

;
BEGIN;

;
CREATE TABLE "meritcommons_user_assignment" (
  "id" serial NOT NULL,
  "meritcommons_user" integer,
  "grp" integer,
  "role" integer,
  "tag" integer,
  "identity" integer,
  PRIMARY KEY ("id"),
  CONSTRAINT "user_group" UNIQUE ("meritcommons_user", "grp"),
  CONSTRAINT "user_identity" UNIQUE ("meritcommons_user", "identity"),
  CONSTRAINT "user_role" UNIQUE ("meritcommons_user", "role"),
  CONSTRAINT "user_tag" UNIQUE ("meritcommons_user", "tag")
);
CREATE INDEX "meritcommons_user_assignment_idx_meritcommons_user" on "meritcommons_user_assignment" ("meritcommons_user");
CREATE INDEX "meritcommons_user_assignment_idx_grp" on "meritcommons_user_assignment" ("grp");
CREATE INDEX "meritcommons_user_assignment_idx_identity" on "meritcommons_user_assignment" ("identity");
CREATE INDEX "meritcommons_user_assignment_idx_role" on "meritcommons_user_assignment" ("role");

;
CREATE TABLE "meritcommons_user_group" (
  "id" serial NOT NULL,
  "create_time" integer NOT NULL,
  "modify_time" integer NOT NULL,
  "common_name" character varying(255) NOT NULL,
  "owner" integer NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "meritcommons_user_group_idx_owner" on "meritcommons_user_group" ("owner");

;
CREATE TABLE "meritcommons_user_tag" (
  "id" serial NOT NULL,
  "create_time" integer NOT NULL,
  "modify_time" integer NOT NULL,
  "common_name" character varying(255) NOT NULL,
  PRIMARY KEY ("id")
);

;
ALTER TABLE "meritcommons_user_assignment" ADD CONSTRAINT "meritcommons_user_assignment_fk_meritcommons_user" FOREIGN KEY ("meritcommons_user")
  REFERENCES "meritcommons_user" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_user_assignment" ADD CONSTRAINT "meritcommons_user_assignment_fk_grp" FOREIGN KEY ("grp")
  REFERENCES "meritcommons_user_group" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_user_assignment" ADD CONSTRAINT "meritcommons_user_assignment_fk_identity" FOREIGN KEY ("identity")
  REFERENCES "meritcommons_user_identity" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_user_assignment" ADD CONSTRAINT "meritcommons_user_assignment_fk_role" FOREIGN KEY ("role")
  REFERENCES "meritcommons_user_role" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_user_group" ADD CONSTRAINT "meritcommons_user_group_fk_owner" FOREIGN KEY ("owner")
  REFERENCES "meritcommons_user" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE meritcommons_link DROP COLUMN role_policy;

;
DROP TABLE meritcommons_user_meritcommonscoinrequest CASCADE;

;
DROP TABLE meritcommons_user_identityuser CASCADE;

;
DROP TABLE meritcommons_user_roleuser CASCADE;

;

COMMIT;

