-- Convert schema '/mnt/hgfs/meritcommons-trunk/var/sql/migrations/_source/deploy/9/001-auto.yml' to '/mnt/hgfs/meritcommons-trunk/var/sql/migrations/_source/deploy/8/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_stream DROP CONSTRAINT meritcommons_stream_type_url_name;

;
DROP INDEX url_name_idx;

;
DROP INDEX url_name_type_idx;

;
ALTER TABLE meritcommons_stream DROP COLUMN url_name;

;
ALTER TABLE meritcommons_stream DROP COLUMN type;

;
ALTER TABLE meritcommons_stream ADD COLUMN title character varying(255);

;

COMMIT;

