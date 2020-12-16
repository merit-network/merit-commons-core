-- Convert schema '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/1000/001-auto.yml' to '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/2000/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_stream_invite ADD COLUMN approved integer DEFAULT 0 NOT NULL;

;

COMMIT;

