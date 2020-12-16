-- Convert schema '/mnt/hgfs/meritcommons-trunk/var/sql/migrations/_source/deploy/10/001-auto.yml' to '/mnt/hgfs/meritcommons-trunk/var/sql/migrations/_source/deploy/11/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_stream DROP CONSTRAINT meritcommons_stream_type_url_name;

;
ALTER TABLE meritcommons_stream ADD CONSTRAINT meritcommons_stream_url_name UNIQUE (url_name);

;

COMMIT;

