-- Convert schema '/usr/local/meritcommons/meritcommons/var/sql/migrations/_source/deploy/5000/001-auto.yml' to '/usr/local/meritcommons/meritcommons/var/sql/migrations/_source/deploy/4000/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_stream_message DROP COLUMN read_only;

;
ALTER TABLE meritcommons_user ADD CONSTRAINT meritcommons_user_fk_notification_inbox FOREIGN KEY (notification_inbox)
  REFERENCES meritcommons_stream (id) ON DELETE CASCADE DEFERRABLE;

;
ALTER TABLE meritcommons_user ADD CONSTRAINT meritcommons_user_fk_personal_inbox FOREIGN KEY (personal_inbox)
  REFERENCES meritcommons_stream (id) ON DELETE CASCADE DEFERRABLE;

;
ALTER TABLE meritcommons_user ADD CONSTRAINT meritcommons_user_fk_personal_outbox FOREIGN KEY (personal_outbox)
  REFERENCES meritcommons_stream (id) ON DELETE CASCADE DEFERRABLE;

;
DROP TABLE meritcommons_user_blockedentity CASCADE;

;

COMMIT;

