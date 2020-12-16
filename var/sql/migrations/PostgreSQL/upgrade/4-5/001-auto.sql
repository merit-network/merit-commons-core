-- Convert schema '/mnt/hgfs/meritcommons-trunk/var/sql/migrations/_source/deploy/4/001-auto.yml' to '/mnt/hgfs/meritcommons-trunk/var/sql/migrations/_source/deploy/5/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE meritcommons_stream ADD COLUMN notification_inbox_user integer;

;
ALTER TABLE meritcommons_stream ADD COLUMN description text;

;
ALTER TABLE meritcommons_stream ADD COLUMN keywords text;

;
ALTER TABLE meritcommons_stream_messagestream ADD COLUMN create_time integer;

;
CREATE INDEX create_time_idx on meritcommons_stream_messagestream (create_time);

;

update meritcommons_stream stream set notification_inbox_user = (select id from meritcommons_user where notification_inbox = stream.id);
update meritcommons_stream_messagestream ms set create_time = (select create_time from meritcommons_stream_message where id = ms.message);

COMMIT;

