-- Convert schema '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/29/001-auto.yml' to '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/30/001-auto.yml':;

;
BEGIN;

;
CREATE TABLE "meritcommons_file" (
  "id" serial NOT NULL,
  "mime_type" character varying(255) NOT NULL,
  "unique_id" character varying(64) NOT NULL,
  "create_time" integer NOT NULL,
  "modify_time" integer NOT NULL,
  "uploader" integer NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "meritcommons_file_idx_uploader" on "meritcommons_file" ("uploader");
CREATE INDEX "file_create_time_idx" on "meritcommons_file" ("create_time");

;
CREATE TABLE "meritcommons_file_variant" (
  "id" serial NOT NULL,
  "common_name" character varying(255) DEFAULT 'original' NOT NULL,
  "storage_type" character varying(255) DEFAULT 'default' NOT NULL,
  "size" integer DEFAULT 0 NOT NULL,
  "url" text NOT NULL,
  "path" text NOT NULL,
  "file" integer NOT NULL,
  "create_time" integer NOT NULL,
  "modify_time" integer NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "meritcommons_file_variant_idx_file" on "meritcommons_file_variant" ("file");
CREATE INDEX "file_variant_create_time_idx" on "meritcommons_file_variant" ("create_time");

;
ALTER TABLE "meritcommons_file" ADD CONSTRAINT "meritcommons_file_fk_uploader" FOREIGN KEY ("uploader")
  REFERENCES "meritcommons_user" ("id") DEFERRABLE;

;
ALTER TABLE "meritcommons_file_variant" ADD CONSTRAINT "meritcommons_file_variant_fk_file" FOREIGN KEY ("file")
  REFERENCES "meritcommons_file" ("id") ON UPDATE CASCADE DEFERRABLE;

;

COMMIT;

