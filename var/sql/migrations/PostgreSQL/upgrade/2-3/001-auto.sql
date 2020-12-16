-- Convert schema '/mnt/hgfs/meritcommons/var/sql/migrations/_source/deploy/2/001-auto.yml' to '/mnt/hgfs/meritcommons/var/sql/migrations/_source/deploy/3/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_user ADD COLUMN notification_inbox integer;

;
CREATE INDEX meritcommons_user_idx_notification_inbox on meritcommons_user (notification_inbox);

;
ALTER TABLE meritcommons_user ADD CONSTRAINT meritcommons_user_fk_notification_inbox FOREIGN KEY (notification_inbox)
  REFERENCES meritcommons_stream (id) DEFERRABLE;

;

COMMIT;

