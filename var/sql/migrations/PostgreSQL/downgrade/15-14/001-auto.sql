-- Convert schema '/mnt/hgfs/meritcommons/var/sql/migrations/_source/deploy/15/001-auto.yml' to '/mnt/hgfs/meritcommons/var/sql/migrations/_source/deploy/14/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_user DROP CONSTRAINT meritcommons_user_fk_notification_inbox;

;
ALTER TABLE meritcommons_user_group DROP CONSTRAINT meritcommons_user_group_fk_owner;

;
ALTER TABLE meritcommons_user ADD CONSTRAINT meritcommons_user_fk_notification_inbox FOREIGN KEY (notification_inbox)
  REFERENCES meritcommons_stream (id) DEFERRABLE;

;
ALTER TABLE meritcommons_user_group ADD CONSTRAINT meritcommons_user_group_fk_owner FOREIGN KEY (owner)
  REFERENCES meritcommons_user (id) DEFERRABLE;

;
DROP TABLE meritcommons_link_collection_role CASCADE;

;

COMMIT;

