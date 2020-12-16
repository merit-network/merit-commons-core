-- custom preflight .. backup roles and identities to a temp table..

BEGIN;

CREATE TABLE meritcommons_user_assignment_temp AS
    SELECT * FROM meritcommons_user_assignment WHERE role IS NOT NULL OR identity IS NOT NULL;

COMMIT;