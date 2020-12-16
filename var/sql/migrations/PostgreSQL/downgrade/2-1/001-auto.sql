-- Convert schema '/mnt/hgfs/meritcommons/var/sql/migrations/_source/deploy/2/001-auto.yml' to '/mnt/hgfs/meritcommons/var/sql/migrations/_source/deploy/1/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_stream_message DROP CONSTRAINT meritcommons_stream_message_fk_regarding;

;
DROP INDEX meritcommons_stream_message_idx_regarding;

;
DROP INDEX meritcommons_stream_message_subtype_idx;

;
DROP INDEX meritcommons_stream_message_regarding_subtype_idx;

;
ALTER TABLE meritcommons_stream_message DROP COLUMN regarding;

;
ALTER TABLE meritcommons_stream_message DROP COLUMN subtype;

;

COMMIT;

