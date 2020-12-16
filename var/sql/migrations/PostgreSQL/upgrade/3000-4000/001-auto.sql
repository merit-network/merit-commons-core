-- Convert schema '/usr/local/meritcommons/meritcommons/var/sql/migrations/_source/deploy/3000/001-auto.yml' to '/usr/local/meritcommons/meritcommons/var/sql/migrations/_source/deploy/4000/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_stream ADD COLUMN background_image_name character varying(255);

;
ALTER TABLE meritcommons_stream ADD COLUMN background_image_size character varying(255);

;
ALTER TABLE meritcommons_stream ADD COLUMN background_image_pretty_size character varying(255);

;
ALTER TABLE meritcommons_stream ADD COLUMN background_image_content_type character varying(255);

;
ALTER TABLE meritcommons_stream ADD COLUMN background_image_modify_time character varying(255);

;
ALTER TABLE meritcommons_stream ADD COLUMN profile_picture_name character varying(255);

;
ALTER TABLE meritcommons_stream ADD COLUMN profile_picture_size character varying(255);

;
ALTER TABLE meritcommons_stream ADD COLUMN profile_picture_pretty_size character varying(255);

;
ALTER TABLE meritcommons_stream ADD COLUMN profile_picture_content_type character varying(255);

;
ALTER TABLE meritcommons_stream ADD COLUMN profile_picture_modify_time character varying(255);

;
ALTER TABLE meritcommons_stream_message_vote DROP CONSTRAINT meritcommons_stream_message_vote_fk_voter;

;
ALTER TABLE meritcommons_stream_message_vote ADD CONSTRAINT meritcommons_stream_message_vote_fk_voter FOREIGN KEY (voter)
  REFERENCES meritcommons_user (id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;

COMMIT;

