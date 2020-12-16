-- Convert schema '/usr/local/meritcommons/meritcommons/var/sql/migrations/_source/deploy/4000/001-auto.yml' to '/usr/local/meritcommons/meritcommons/var/sql/migrations/_source/deploy/3000/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_stream DROP COLUMN background_image_name;

;
ALTER TABLE meritcommons_stream DROP COLUMN background_image_size;

;
ALTER TABLE meritcommons_stream DROP COLUMN background_image_pretty_size;

;
ALTER TABLE meritcommons_stream DROP COLUMN background_image_content_type;

;
ALTER TABLE meritcommons_stream DROP COLUMN background_image_modify_time;

;
ALTER TABLE meritcommons_stream DROP COLUMN profile_picture_name;

;
ALTER TABLE meritcommons_stream DROP COLUMN profile_picture_size;

;
ALTER TABLE meritcommons_stream DROP COLUMN profile_picture_pretty_size;

;
ALTER TABLE meritcommons_stream DROP COLUMN profile_picture_content_type;

;
ALTER TABLE meritcommons_stream DROP COLUMN profile_picture_modify_time;

;
ALTER TABLE meritcommons_stream_message_vote DROP CONSTRAINT meritcommons_stream_message_vote_fk_voter;

;
ALTER TABLE meritcommons_stream_message_vote ADD CONSTRAINT meritcommons_stream_message_vote_fk_voter FOREIGN KEY (voter)
  REFERENCES meritcommons_user (id) DEFERRABLE;

;

COMMIT;

