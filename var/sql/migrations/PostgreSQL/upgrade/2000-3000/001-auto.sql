-- Convert schema '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/2000/001-auto.yml' to '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/3000/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_link ADD COLUMN icon_class text;

;
ALTER TABLE meritcommons_link_collection ADD COLUMN icon_class text;

;

COMMIT;

