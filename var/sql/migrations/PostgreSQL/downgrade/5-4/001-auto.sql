-- Convert schema '/mnt/hgfs/meritcommons-trunk/var/sql/migrations/_source/deploy/5/001-auto.yml' to '/mnt/hgfs/meritcommons-trunk/var/sql/migrations/_source/deploy/4/001-auto.yml':;

;
BEGIN;

;
DROP INDEX create_time_idx;

;
ALTER TABLE meritcommons_stream DROP COLUMN notification_inbox_user;

;
ALTER TABLE meritcommons_stream DROP COLUMN description;

;
ALTER TABLE meritcommons_stream DROP COLUMN keywords;

;
ALTER TABLE meritcommons_stream_messagestream DROP COLUMN create_time;

;

COMMIT;

