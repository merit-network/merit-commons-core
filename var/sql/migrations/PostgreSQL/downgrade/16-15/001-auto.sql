-- Convert schema '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/16/001-auto.yml' to '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/15/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_user_assignment DROP CONSTRAINT user_group;

;
ALTER TABLE meritcommons_user_assignment DROP CONSTRAINT user_identity;

;
ALTER TABLE meritcommons_user_assignment DROP CONSTRAINT user_role;

;
ALTER TABLE meritcommons_user_assignment DROP CONSTRAINT user_tag;

;
ALTER TABLE meritcommons_stream_message DROP COLUMN regarding_stream;

;

COMMIT;

