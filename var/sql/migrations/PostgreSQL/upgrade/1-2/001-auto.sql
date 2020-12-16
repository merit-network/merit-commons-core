-- Convert schema '/mnt/hgfs/meritcommons/var/sql/migrations/_source/deploy/1/001-auto.yml' to '/mnt/hgfs/meritcommons/var/sql/migrations/_source/deploy/2/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_stream_message ADD COLUMN regarding character varying(64);

;
ALTER TABLE meritcommons_stream_message ADD COLUMN subtype character varying(64);

;
CREATE INDEX meritcommons_stream_message_idx_regarding on meritcommons_stream_message (regarding);

;
CREATE INDEX meritcommons_stream_message_subtype_idx on meritcommons_stream_message (subtype);

;
CREATE INDEX meritcommons_stream_message_regarding_subtype_idx on meritcommons_stream_message (regarding, subtype);

;
ALTER TABLE meritcommons_stream_message ADD CONSTRAINT meritcommons_stream_message_fk_regarding FOREIGN KEY (regarding)
  REFERENCES meritcommons_stream_message (unique_id) DEFERRABLE;

;

COMMIT;

