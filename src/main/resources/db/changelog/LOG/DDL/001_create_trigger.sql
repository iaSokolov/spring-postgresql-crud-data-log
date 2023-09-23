CREATE TABLE IF NOT EXISTS record_log
(
    "timestamp"  timestamp with time zone DEFAULT now() NOT NULL,
    "user"       text NOT NULL            DEFAULT CURRENT_USER,
    action       text NOT NULL,
    table_schema text NOT NULL,
    table_name   text NOT NULL,
    old_row      jsonb,
    new_row      jsonb,
    CONSTRAINT record_log_check CHECK (
        CASE action
            WHEN 'INSERT' THEN old_row IS NULL
            WHEN 'DELETE' THEN new_row IS NULL
            END
        )
) PARTITION BY LIST (table_schema);

CREATE TABLE IF NOT EXISTS public_record_log PARTITION OF record_log
    FOR VALUES IN ('main')
    PARTITION BY LIST (table_name);

CREATE FUNCTION log_insert()
    RETURNS TRIGGER
    LANGUAGE PLPGSQL
AS
$$
BEGIN
    INSERT INTO main.record_log(action, table_schema, table_name, new_row)
    SELECT TG_OP, TG_TABLE_SCHEMA, TG_RELNAME, to_jsonb(new_table)
    FROM new_table;
    RETURN NULL;
END;
$$;

CREATE FUNCTION log_update()
    RETURNS TRIGGER
    LANGUAGE PLPGSQL
AS
$$
BEGIN
    INSERT INTO main.record_log(action, table_schema, table_name, old_row, new_row)
    SELECT TG_OP, TG_TABLE_SCHEMA, TG_RELNAME, old_row, new_row
    FROM UNNEST(
                 ARRAY(SELECT to_jsonb(old_table) FROM old_table),
                 ARRAY(SELECT to_jsonb(new_table) FROM new_table))
             AS t(old_row, new_row);
    RETURN NULL;
END;
$$;

CREATE FUNCTION log_delete()
    RETURNS TRIGGER
    LANGUAGE PLPGSQL
AS
$$
BEGIN
    INSERT INTO main.record_log(action, table_schema, table_name, old_row)
    SELECT TG_OP, TG_TABLE_SCHEMA, TG_RELNAME, to_jsonb(old_table)
    FROM old_table;
    RETURN NULL;
END;
$$;