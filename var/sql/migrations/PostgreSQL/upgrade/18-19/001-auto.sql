-- Convert schema '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/18/001-auto.yml' to '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/19/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_stream_message ADD COLUMN about character varying(64);

;
CREATE INDEX meritcommons_stream_message_idx_about on meritcommons_stream_message (about);

;
ALTER TABLE meritcommons_stream_message ADD CONSTRAINT meritcommons_stream_message_fk_about FOREIGN KEY (about)
  REFERENCES meritcommons_stream_message (unique_id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;

COMMIT;

