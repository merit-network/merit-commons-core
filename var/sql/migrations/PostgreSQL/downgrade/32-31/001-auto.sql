-- Convert schema '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/32/001-auto.yml' to '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/31/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_stream_message DROP COLUMN subject;

;
ALTER TABLE meritcommons_stream_message DROP COLUMN nag_interval;

;
ALTER TABLE meritcommons_stream_message DROP COLUMN submitter_mask;

;

COMMIT;

