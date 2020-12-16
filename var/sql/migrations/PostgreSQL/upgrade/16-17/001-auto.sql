-- Convert schema '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/16/001-auto.yml' to '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/17/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_stream_message DROP CONSTRAINT meritcommons_stream_message_fk_regarding;

;
ALTER TABLE meritcommons_stream_message DROP CONSTRAINT meritcommons_stream_message_fk_submitter;

;
ALTER TABLE meritcommons_stream_message_tag DROP CONSTRAINT meritcommons_stream_message_tag_fk_meritcommons_user;

;
CREATE INDEX meritcommons_stream_message_idx_regarding_stream on meritcommons_stream_message (regarding_stream);

;
ALTER TABLE meritcommons_stream_message ADD CONSTRAINT meritcommons_stream_message_fk_regarding FOREIGN KEY (regarding)
  REFERENCES meritcommons_stream_message (unique_id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE meritcommons_stream_message ADD CONSTRAINT meritcommons_stream_message_fk_regarding_stream FOREIGN KEY (regarding_stream)
  REFERENCES meritcommons_stream (unique_id) DEFERRABLE;

;
ALTER TABLE meritcommons_stream_message ADD CONSTRAINT meritcommons_stream_message_fk_submitter FOREIGN KEY (submitter)
  REFERENCES meritcommons_user (id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE meritcommons_stream_message_tag ADD CONSTRAINT meritcommons_stream_message_tag_fk_meritcommons_user FOREIGN KEY (meritcommons_user)
  REFERENCES meritcommons_user (id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;

COMMIT;

