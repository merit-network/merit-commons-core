-- Convert schema '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/29/001-auto.yml' to '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/28/001-auto.yml':;

;
BEGIN;

;
DROP INDEX meritcommons_stream_messagestream_idx_stream_message;

;
DROP TABLE meritcommons_changelog CASCADE;

;

COMMIT;

