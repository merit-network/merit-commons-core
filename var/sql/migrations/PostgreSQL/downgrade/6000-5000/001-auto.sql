-- Convert schema '/usr/local/meritcommons/meritcommons/var/sql/migrations/_source/deploy/6000/001-auto.yml' to '/usr/local/meritcommons/meritcommons/var/sql/migrations/_source/deploy/5000/001-auto.yml':;

;
BEGIN;

;
DROP INDEX personal_inbox_user_idx;

;
DROP INDEX personal_outbox_user_idx;

;
DROP INDEX notification_inbox_user_idx;

;

COMMIT;

