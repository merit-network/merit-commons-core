-- Convert schema '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/34/001-auto.yml' to '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/35/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_stream ADD COLUMN membership_requires_moderator_approval integer NOT NULL DEFAULT 0;

;

COMMIT;

