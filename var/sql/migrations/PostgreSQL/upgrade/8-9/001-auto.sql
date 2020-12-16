-- Convert schema '/mnt/hgfs/meritcommons-trunk/var/sql/migrations/_source/deploy/8/001-auto.yml' to '/mnt/hgfs/meritcommons-trunk/var/sql/migrations/_source/deploy/9/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_stream DROP COLUMN title;

;
ALTER TABLE meritcommons_stream ADD COLUMN url_name character varying(255);

;
ALTER TABLE meritcommons_stream ADD COLUMN type character varying DEFAULT 'user' NOT NULL;

;
CREATE INDEX url_name_idx on meritcommons_stream (url_name);

;
CREATE INDEX url_name_type_idx on meritcommons_stream (url_name, type);

;
ALTER TABLE meritcommons_stream ADD CONSTRAINT meritcommons_stream_type_url_name UNIQUE (type, url_name);

;

COMMIT;

