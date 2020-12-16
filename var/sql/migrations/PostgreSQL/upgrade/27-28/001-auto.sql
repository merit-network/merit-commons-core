-- Convert schema '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/27/001-auto.yml' to '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/28/001-auto.yml':;

;
BEGIN;

;
CREATE TABLE "meritcommons_user_role_exception" (
  "id" serial NOT NULL,
  "meritcommons_user" integer NOT NULL,
  "role" integer NOT NULL,
  "create_time" integer NOT NULL,
  "modify_time" integer NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "role_exception" UNIQUE ("meritcommons_user", "role")
);
CREATE INDEX "meritcommons_user_role_exception_idx_meritcommons_user" on "meritcommons_user_role_exception" ("meritcommons_user");
CREATE INDEX "meritcommons_user_role_exception_idx_role" on "meritcommons_user_role_exception" ("role");

;
ALTER TABLE "meritcommons_user_role_exception" ADD CONSTRAINT "meritcommons_user_role_exception_fk_meritcommons_user" FOREIGN KEY ("meritcommons_user")
  REFERENCES "meritcommons_user" ("id") DEFERRABLE;

;
ALTER TABLE "meritcommons_user_role_exception" ADD CONSTRAINT "meritcommons_user_role_exception_fk_role" FOREIGN KEY ("role")
  REFERENCES "meritcommons_user_role" ("id") DEFERRABLE;

;

COMMIT;

