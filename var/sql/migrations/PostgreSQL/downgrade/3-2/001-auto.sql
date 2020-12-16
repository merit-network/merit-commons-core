-- Convert schema '/mnt/hgfs/meritcommons/var/sql/migrations/_source/deploy/3/001-auto.yml' to '/mnt/hgfs/meritcommons/var/sql/migrations/_source/deploy/2/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_user DROP CONSTRAINT meritcommons_user_fk_notification_inbox;

;
DROP INDEX meritcommons_user_idx_notification_inbox;

;
ALTER TABLE meritcommons_user DROP COLUMN notification_inbox;

;

COMMIT;

