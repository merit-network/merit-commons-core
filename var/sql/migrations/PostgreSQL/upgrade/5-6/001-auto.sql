-- Convert schema '/mnt/hgfs/meritcommons-trunk/var/sql/migrations/_source/deploy/5/001-auto.yml' to '/mnt/hgfs/meritcommons-trunk/var/sql/migrations/_source/deploy/6/001-auto.yml':;

;
BEGIN;

;
CREATE INDEX meritcommons_stream_message_render_as_idx on meritcommons_stream_message (render_as);

;

COMMIT;

