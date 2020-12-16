-- Convert schema '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/22/001-auto.yml' to '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/21/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_stream DROP COLUMN show_publicly;

;
ALTER TABLE meritcommons_stream DROP COLUMN display_subscribers;

;

COMMIT;

