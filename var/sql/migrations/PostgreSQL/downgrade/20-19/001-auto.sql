-- Convert schema '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/20/001-auto.yml' to '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/19/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_link DROP COLUMN target;

;

COMMIT;

