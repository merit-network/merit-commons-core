-- Convert schema '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/30/001-auto.yml' to '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/31/001-auto.yml':;

;
BEGIN;

;
CREATE INDEX file_unique_id_idx on meritcommons_file (unique_id);

;

COMMIT;

