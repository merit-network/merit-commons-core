-- Convert schema '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/21/001-auto.yml' to '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/22/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_stream ADD COLUMN show_publicly integer DEFAULT 0 NOT NULL;

;
ALTER TABLE meritcommons_stream ADD COLUMN display_subscribers integer DEFAULT 0 NOT NULL;

UPDATE meritcommons_stream set show_publicly = 0;
UPDATE meritcommons_stream set display_subscribers = 0;

;

COMMIT;

