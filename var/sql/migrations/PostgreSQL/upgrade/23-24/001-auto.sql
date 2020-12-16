-- Convert schema '/home/adam/codedevel/meritcommons/var/sql/migrations/_source/deploy/23/001-auto.yml' to '/home/adam/codedevel/meritcommons/var/sql/migrations/_source/deploy/24/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_stream ADD COLUMN subtype character varying(255);

;

COMMIT;

