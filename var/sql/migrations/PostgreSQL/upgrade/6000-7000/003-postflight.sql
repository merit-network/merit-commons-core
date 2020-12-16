-- custom preflight .. copy into useridentity and userrole

BEGIN;

INSERT INTO meritcommons_user_identityuser (meritcommons_user, identity) (
    SELECT 
        meritcommons_user_assignment_temp.meritcommons_user, meritcommons_user_assignment_temp.identity 
    FROM
        meritcommons_user_assignment_temp 
    WHERE meritcommons_user_assignment_temp.identity IS NOT NULL
);

INSERT INTO meritcommons_user_roleuser (meritcommons_user, role) (
    SELECT 
        meritcommons_user_assignment_temp.meritcommons_user, meritcommons_user_assignment_temp.role
    FROM
        meritcommons_user_assignment_temp 
    WHERE meritcommons_user_assignment_temp.role IS NOT NULL
);

-- drop the temp table as we're done with it!

DROP TABLE meritcommons_user_assignment_temp;

COMMIT;