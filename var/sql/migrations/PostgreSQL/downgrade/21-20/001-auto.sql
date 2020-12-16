-- Convert schema '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/21/001-auto.yml' to '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/20/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_link DROP COLUMN type;

;
ALTER TABLE meritcommons_link ALTER COLUMN target SET DEFAULT '_new';

;
DROP TABLE meritcommons_link_role CASCADE;

;

COMMIT;

