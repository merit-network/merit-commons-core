-- Convert schema '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/23/001-auto.yml' to '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/22/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_link DROP COLUMN keywords;

;

COMMIT;

