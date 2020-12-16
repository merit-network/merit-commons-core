-- Convert schema '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/25/001-auto.yml' to '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/24/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE ap_casserver_ticket ALTER COLUMN service TYPE character varying(255);

;
ALTER TABLE ap_casserver_ticket ALTER COLUMN pgt_url TYPE character varying(255);

;

COMMIT;

