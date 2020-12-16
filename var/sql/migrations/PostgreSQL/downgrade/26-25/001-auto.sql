-- Convert schema '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/26/001-auto.yml' to '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/25/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_stream DROP COLUMN subscriber_count;

;
ALTER TABLE meritcommons_stream DROP COLUMN author_count;

;
ALTER TABLE meritcommons_stream DROP COLUMN moderator_count;

;
ALTER TABLE meritcommons_stream DROP COLUMN members_can_invite;

;
DROP TABLE meritcommons_stream_invite CASCADE;

;

COMMIT;

