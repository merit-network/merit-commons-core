-- custom preflight .. backup roles and identities to a temp table..

BEGIN;

CREATE TABLE meritcommons_user_meritcommonscointransaction_temp AS
    SELECT * FROM meritcommons_user_meritcommonscointransaction;

COMMIT;