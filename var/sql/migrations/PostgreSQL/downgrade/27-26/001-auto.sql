-- Convert schema '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/27/001-auto.yml' to '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/26/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_stream DROP COLUMN allow_add_moderator;

;

COMMIT;

