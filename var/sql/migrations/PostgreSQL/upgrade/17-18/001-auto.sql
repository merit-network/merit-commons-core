-- Convert schema '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/17/001-auto.yml' to '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/18/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_stream ADD COLUMN short_name character varying(8);

;

COMMIT;

