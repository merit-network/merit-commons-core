-- custom postflight

BEGIN;

UPDATE meritcommons_user_meritcommonscointransaction new
    SET transaction_id = temp.unique_id
    FROM meritcommons_user_meritcommonscointransaction_temp temp
    WHERE new.id = temp.id;

-- drop the temp table as we're done with it!

DROP TABLE meritcommons_user_meritcommonscointransaction_temp;

COMMIT;