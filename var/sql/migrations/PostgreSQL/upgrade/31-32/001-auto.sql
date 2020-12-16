-- Convert schema '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/31/001-auto.yml' to '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/32/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_stream_message ADD COLUMN subject text;

;
ALTER TABLE meritcommons_stream_message ADD COLUMN nag_interval integer DEFAULT 0 NOT NULL;

;
ALTER TABLE meritcommons_stream_message ADD COLUMN submitter_mask text;

;

COMMIT;

