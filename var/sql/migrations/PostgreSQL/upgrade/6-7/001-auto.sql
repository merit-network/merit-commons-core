-- Convert schema '/mnt/hgfs/meritcommons-trunk/var/sql/migrations/_source/deploy/6/001-auto.yml' to '/mnt/hgfs/meritcommons-trunk/var/sql/migrations/_source/deploy/7/001-auto.yml':;

;
BEGIN;

;
CREATE TABLE "meritcommons_dataagent" (
  "id" serial NOT NULL,
  "enc_pub_key" character varying(255),
  "sign_pub_key" character varying(255),
  "create_time" integer NOT NULL,
  "common_name" character varying(255) NOT NULL,
  "unique_id" character varying(64) NOT NULL,
  "source_user" integer,
  PRIMARY KEY ("id")
);
CREATE INDEX "meritcommons_dataagent_uuid_idx" on "meritcommons_dataagent" ("unique_id");
CREATE INDEX "meritcommons_dataagent_cn_idx" on "meritcommons_dataagent" ("common_name");

;

COMMIT;

