-- Convert schema '/usr/local/meritcommons/meritcommons/var/sql/migrations/_source/deploy/5000/001-auto.yml' to '/usr/local/meritcommons/meritcommons/var/sql/migrations/_source/deploy/6000/001-auto.yml':;

;
BEGIN;

;
CREATE INDEX personal_inbox_user_idx on meritcommons_stream (personal_inbox_user);

;
CREATE INDEX personal_outbox_user_idx on meritcommons_stream (personal_outbox_user);

;
CREATE INDEX notification_inbox_user_idx on meritcommons_stream (notification_inbox_user);

;

COMMIT;

