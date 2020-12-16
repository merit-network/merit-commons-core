-- Convert schema '/mnt/hgfs/meritcommons-trunk/var/sql/migrations/_source/deploy/9/001-auto.yml' to '/mnt/hgfs/meritcommons-trunk/var/sql/migrations/_source/deploy/10/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_stream ADD COLUMN external_unique_id character varying(255);

;
ALTER TABLE meritcommons_user ADD COLUMN external_unique_id character varying(255);

;
ALTER TABLE meritcommons_stream ALTER COLUMN type DROP NOT NULL;
ALTER TABLE meritcommons_stream ALTER COLUMN type DROP DEFAULT;
CREATE INDEX meritcommons_stream_external_unique_id_idx on meritcommons_stream (external_unique_id);

;
CREATE INDEX meritcommons_stream_message_external_unique_id_idx on meritcommons_stream_message (external_unique_id);

;
CREATE INDEX meritcommons_user_external_unique_id_idx on meritcommons_user (external_unique_id);

;
ALTER TABLE meritcommons_stream ADD CONSTRAINT meritcommons_stream_external_unique_id UNIQUE (external_unique_id);

;
ALTER TABLE meritcommons_stream_message ADD CONSTRAINT meritcommons_stream_message_external_unique_id UNIQUE (external_unique_id);

;
ALTER TABLE meritcommons_user ADD CONSTRAINT meritcommons_user_external_unique_id UNIQUE (external_unique_id);

;

COMMIT;

