-- Convert schema '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/33/001-auto.yml' to '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/34/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_stream ADD COLUMN private integer DEFAULT 0 NOT NULL;

;

COMMIT;

