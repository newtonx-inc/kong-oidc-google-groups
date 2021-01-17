return {
    postgresql = {
        up = [[
            CREATE TABLE IF NOT EXISTS google_group_memberships (
                google_user VARCHAR (255) PRIMARY KEY,
                google_groups TEXT []
                created_at TIMESTAMP,
                updated_at TIMESTAMP,
            );

            DO $$
            BEGIN
                CREATE INDEX IF NOT EXISTS google_group_memberships_user
                                    ON google_group_memberships (google_user);
            EXCEPTION WHEN UNDEFINED_COLUMN THEN
            -- Do nothing, accept existing state
            END$$;

            CREATE TABLE IF NOT EXISTS google_tokens (
                name VARCHAR (255) PRIMARY KEY,
                value TEXT,
                expires_at FLOAT,
                created_at TIMESTAMP,
                updated_at TIMESTAMP,
            );

            DO $$
            BEGIN
                CREATE INDEX IF NOT EXISTS google_tokens_name
                                    ON google_tokens (name);
            EXCEPTION WHEN UNDEFINED_COLUMN THEN
            -- Do nothing, accept existing state
            END$$;
        ]],
    },
}