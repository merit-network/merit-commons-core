-- Convert schema '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/15/001-auto.yml' to '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/16/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_stream_message ADD COLUMN regarding_stream character varying(64);

;
ALTER TABLE meritcommons_user_assignment ADD CONSTRAINT user_group UNIQUE (meritcommons_user, grp);

;
ALTER TABLE meritcommons_user_assignment ADD CONSTRAINT user_identity UNIQUE (meritcommons_user, identity);

;
ALTER TABLE meritcommons_user_assignment ADD CONSTRAINT user_role UNIQUE (meritcommons_user, role);

;
ALTER TABLE meritcommons_user_assignment ADD CONSTRAINT user_tag UNIQUE (meritcommons_user, tag);

;

COMMIT;

