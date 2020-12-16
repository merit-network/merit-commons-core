-- Convert schema '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/35/001-auto.yml' to '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/1000/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_stream_invite DROP CONSTRAINT meritcommons_stream_invite_fk_invitee;

;
ALTER TABLE meritcommons_stream_invite DROP CONSTRAINT meritcommons_stream_invite_fk_stream;

;
ALTER TABLE meritcommons_stream_invite ADD CONSTRAINT meritcommons_stream_invite_fk_invitee FOREIGN KEY (invitee)
  REFERENCES meritcommons_user (id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE meritcommons_stream_invite ADD CONSTRAINT meritcommons_stream_invite_fk_stream FOREIGN KEY (stream)
  REFERENCES meritcommons_stream (id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
DROP TABLE ap_casserver_ticket CASCADE;

;

COMMIT;

