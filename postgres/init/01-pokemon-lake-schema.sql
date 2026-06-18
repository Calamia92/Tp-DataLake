CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
BEGIN
    CREATE TYPE pokemon_file_type AS ENUM (
        'raw_json',
        'sprite',
        'official_artwork',
        'report_csv',
        'error_log',
        'other'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    CREATE TYPE file_ingestion_status AS ENUM (
        'success',
        'failed',
        'skipped'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS pokemon (
    pokemon_id INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    generation SMALLINT NOT NULL,
    primary_type TEXT NOT NULL,
    secondary_type TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pokemon_files (
    file_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pokemon_id INTEGER NOT NULL REFERENCES pokemon(pokemon_id),
    bucket_name TEXT NOT NULL,
    object_key TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_type pokemon_file_type NOT NULL,
    mime_type TEXT,
    size_bytes BIGINT CHECK (size_bytes IS NULL OR size_bytes >= 0),
    checksum_sha256 CHAR(64) CHECK (
        checksum_sha256 IS NULL
        OR checksum_sha256 ~ '^[a-f0-9]{64}$'
    ),
    source TEXT NOT NULL,
    source_url TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    internal_url TEXT GENERATED ALWAYS AS ('s3://' || bucket_name || '/' || object_key) STORED,
    ingested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (bucket_name, object_key)
);

CREATE TABLE IF NOT EXISTS file_ingestion_log (
    log_id BIGSERIAL PRIMARY KEY,
    file_id UUID REFERENCES pokemon_files(file_id),
    pokemon_id INTEGER REFERENCES pokemon(pokemon_id),
    file_name TEXT NOT NULL,
    bucket_name TEXT NOT NULL,
    object_key TEXT NOT NULL,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    source TEXT NOT NULL,
    status file_ingestion_status NOT NULL,
    message TEXT,
    size_bytes BIGINT CHECK (size_bytes IS NULL OR size_bytes >= 0),
    checksum_sha256 CHAR(64) CHECK (
        checksum_sha256 IS NULL
        OR checksum_sha256 ~ '^[a-f0-9]{64}$'
    ),
    workflow_run_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pokemon_files_pokemon_id
    ON pokemon_files(pokemon_id);

CREATE INDEX IF NOT EXISTS idx_pokemon_files_bucket_object
    ON pokemon_files(bucket_name, object_key);

CREATE INDEX IF NOT EXISTS idx_file_ingestion_log_processed_at
    ON file_ingestion_log(processed_at DESC);

CREATE INDEX IF NOT EXISTS idx_file_ingestion_log_status
    ON file_ingestion_log(status);

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_pokemon_files_updated_at ON pokemon_files;
CREATE TRIGGER trg_pokemon_files_updated_at
BEFORE UPDATE ON pokemon_files
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE OR REPLACE VIEW pokemon_file_catalog AS
SELECT
    pf.file_id,
    pf.pokemon_id,
    p.name AS pokemon_name,
    p.primary_type,
    p.secondary_type,
    pf.bucket_name,
    pf.object_key,
    pf.file_name,
    pf.file_type,
    pf.mime_type,
    pf.size_bytes,
    pf.checksum_sha256,
    pf.internal_url,
    pf.source,
    pf.ingested_at,
    pf.created_at,
    pf.updated_at
FROM pokemon_files pf
JOIN pokemon p ON p.pokemon_id = pf.pokemon_id;

INSERT INTO pokemon (pokemon_id, name, generation, primary_type, secondary_type)
VALUES
    (1, 'bulbasaur', 1, 'grass', 'poison'),
    (4, 'charmander', 1, 'fire', NULL),
    (7, 'squirtle', 1, 'water', NULL),
    (25, 'pikachu', 1, 'electric', NULL),
    (39, 'jigglypuff', 1, 'normal', 'fairy'),
    (150, 'mewtwo', 1, 'psychic', NULL)
ON CONFLICT (pokemon_id) DO UPDATE
SET
    name = EXCLUDED.name,
    generation = EXCLUDED.generation,
    primary_type = EXCLUDED.primary_type,
    secondary_type = EXCLUDED.secondary_type;
