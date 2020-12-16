-- Convert schema '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/19/001-auto.yml' to '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/18/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_stream_message DROP CONSTRAINT meritcommons_stream_message_fk_about;

;
DROP INDEX meritcommons_stream_message_idx_about;

;
ALTER TABLE meritcommons_stream_message DROP COLUMN about;

;

COMMIT;

