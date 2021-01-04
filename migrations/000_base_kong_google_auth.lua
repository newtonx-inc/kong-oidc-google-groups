return {
    postgresql = {
        up = [[
            CREATE TABLE IF NOT EXISTS google_group_memberships (
                google_user VARCHAR (255) PRIMARY KEY,
                created_at TIMESTAMP WITHOUT TIME ZONE,
                google_groups TEXT []
            );

            DO $$
            BEGIN
                CREATE INDEX IF NOT EXISTS google_group_memberships_user
                                    ON google_group_memberships (google_user);
            EXCEPTION WHEN UNDEFINED_COLUMN THEN
            -- Do nothing, accept existing state
            END$$;
        ]],
    },
}