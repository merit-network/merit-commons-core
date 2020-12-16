-- Convert schema '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/20/001-auto.yml' to '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/21/001-auto.yml':;

;
BEGIN;

ALTER TABLE "meritcommons_link_collection_role" DROP CONSTRAINT "link_roles";
ALTER TABLE "meritcommons_link_collection_role" ADD CONSTRAINT "collection_roles" UNIQUE ("role", "collection");

;
CREATE TABLE "meritcommons_link_role" (
  "id" serial NOT NULL,
  "role" integer NOT NULL,
  "link" integer NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "link_roles" UNIQUE ("role", "link")
);
CREATE INDEX "meritcommons_link_role_idx_link" on "meritcommons_link_role" ("link");
CREATE INDEX "meritcommons_link_role_idx_role" on "meritcommons_link_role" ("role");

;
ALTER TABLE "meritcommons_link_role" ADD CONSTRAINT "meritcommons_link_role_fk_link" FOREIGN KEY ("link")
  REFERENCES "meritcommons_link" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_link_role" ADD CONSTRAINT "meritcommons_link_role_fk_role" FOREIGN KEY ("role")
  REFERENCES "meritcommons_user_role" ("id") DEFERRABLE;

;
ALTER TABLE meritcommons_link ADD COLUMN type character varying;

;
ALTER TABLE meritcommons_link ALTER COLUMN target SET DEFAULT '_blank';

;

COMMIT;

