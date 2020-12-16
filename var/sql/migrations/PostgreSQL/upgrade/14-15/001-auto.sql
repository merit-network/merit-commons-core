-- Convert schema '/mnt/hgfs/meritcommons/var/sql/migrations/_source/deploy/14/001-auto.yml' to '/mnt/hgfs/meritcommons/var/sql/migrations/_source/deploy/15/001-auto.yml':;

;
BEGIN;

;
CREATE TABLE "meritcommons_link_collection_role" (
  "id" serial NOT NULL,
  "role" integer NOT NULL,
  "collection" integer NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "link_roles" UNIQUE ("role", "collection")
);
CREATE INDEX "meritcommons_link_collection_role_idx_collection" on "meritcommons_link_collection_role" ("collection");
CREATE INDEX "meritcommons_link_collection_role_idx_role" on "meritcommons_link_collection_role" ("role");

;
ALTER TABLE "meritcommons_link_collection_role" ADD CONSTRAINT "meritcommons_link_collection_role_fk_collection" FOREIGN KEY ("collection")
  REFERENCES "meritcommons_link_collection" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_link_collection_role" ADD CONSTRAINT "meritcommons_link_collection_role_fk_role" FOREIGN KEY ("role")
  REFERENCES "meritcommons_user_role" ("id") DEFERRABLE;

;
ALTER TABLE meritcommons_user DROP CONSTRAINT meritcommons_user_fk_notification_inbox;

;
ALTER TABLE meritcommons_user_group DROP CONSTRAINT meritcommons_user_group_fk_owner;

;
ALTER TABLE meritcommons_user ADD CONSTRAINT meritcommons_user_fk_notification_inbox FOREIGN KEY (notification_inbox)
  REFERENCES meritcommons_stream (id) ON DELETE CASCADE DEFERRABLE;

;
ALTER TABLE meritcommons_user_group ADD CONSTRAINT meritcommons_user_group_fk_owner FOREIGN KEY (owner)
  REFERENCES meritcommons_user (id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;

COMMIT;

