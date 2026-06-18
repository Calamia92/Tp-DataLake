#!/usr/bin/env bash
set -euo pipefail

if docker compose version >/dev/null 2>&1; then
  COMPOSE=(docker compose)
else
  COMPOSE=(docker-compose)
fi

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

POSTGRES_DB="${POSTGRES_DB:-pokemon_lake}"
POSTGRES_USER="${POSTGRES_USER:-pokemon}"
MINIO_ROOT_USER="${MINIO_ROOT_USER:-minioadmin}"
MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD:-minioadmin123}"

TS="$(date -u +%Y%m%dT%H%M%SZ)"
RAW_BUCKET="raw-pokemon"
IMAGE_BUCKET="pokemon-images"
REPORT_BUCKET="reports"
REPORT_NAME="pokemon_ingestion_report_${TS}.csv"
REPORT_KEY="ingestion/${REPORT_NAME}"
REPORT_FILE="data/generated/reports/${REPORT_NAME}"

POKEMON_ROWS=(
  "1|bulbasaur|7|69|64|grass,poison|#78c850|#a7db8d"
  "4|charmander|6|85|62|fire|#f08030|#f5ac78"
  "7|squirtle|5|90|63|water|#6890f0|#9db7f5"
  "25|pikachu|4|60|112|electric|#f7d02c|#ffe873"
  "39|jigglypuff|5|55|95|normal,fairy|#ffb6c1|#ffd1dc"
  "150|mewtwo|20|1220|340|psychic|#a040a0|#d6a2e8"
)

mkdir -p data/generated/raw data/generated/reports

types_to_json() {
  local types_csv="$1"
  local result="["
  local separator=""
  IFS=',' read -r -a types <<< "$types_csv"

  for type_name in "${types[@]}"; do
    result+="${separator}\"${type_name}\""
    separator=","
  done

  result+="]"
  printf '%s' "$result"
}

append_sql_value() {
  local pokemon_id="$1"
  local bucket_name="$2"
  local object_key="$3"
  local file_name="$4"
  local file_type="$5"
  local mime_type="$6"
  local size_bytes="$7"
  local checksum="$8"
  local source="$9"
  local source_url="${10}"
  local metadata_json="${11}"

  if [[ -n "${SQL_VALUES:-}" ]]; then
    SQL_VALUES+=","
  fi

  SQL_VALUES+=$'\n        '
  SQL_VALUES+="(${pokemon_id}, '${bucket_name}', '${object_key}', '${file_name}', '${file_type}', '${mime_type}', ${size_bytes}, '${checksum}', '${source}', ${source_url}, '${metadata_json}'::jsonb)"
}

REPORT_ROWS="pokemon_id,pokemon_name,bucket_name,object_key,file_name,file_type,size_bytes,checksum_sha256,status,processed_at"
UPLOAD_COMMAND="mc alias set local http://minio:9000 ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD} >/dev/null"
SQL_VALUES=""

for row in "${POKEMON_ROWS[@]}"; do
  IFS='|' read -r POKEMON_ID POKEMON_NAME HEIGHT WEIGHT BASE_EXPERIENCE TYPES_CSV PRIMARY_COLOR SECONDARY_COLOR <<< "$row"

  TYPES_JSON="$(types_to_json "$TYPES_CSV")"
  DISPLAY_NAME="$(printf '%s' "$POKEMON_NAME" | tr '[:lower:]' '[:upper:]')"
  RAW_NAME="pokemon_${POKEMON_ID}_${POKEMON_NAME}_${TS}.json"
  IMAGE_NAME="pokemon_${POKEMON_ID}_${POKEMON_NAME}_badge_${TS}.svg"
  RAW_KEY="pokeapi/pokemon/${POKEMON_ID}/${RAW_NAME}"
  IMAGE_KEY="generated/badges/${POKEMON_ID}/${IMAGE_NAME}"
  RAW_FILE="data/generated/raw/${RAW_NAME}"
  IMAGE_FILE="data/generated/raw/${IMAGE_NAME}"

  cat > "$RAW_FILE" <<JSON
{
  "id": ${POKEMON_ID},
  "name": "${POKEMON_NAME}",
  "height": ${HEIGHT},
  "weight": ${WEIGHT},
  "base_experience": ${BASE_EXPERIENCE},
  "types": ${TYPES_JSON},
  "sprites": {
    "official_artwork": "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/${POKEMON_ID}.png"
  },
  "source": "local-demo-pokeapi-shape",
  "generated_at": "${TS}"
}
JSON

  RAW_SIZE="$(wc -c < "$RAW_FILE" | tr -d ' ')"
  RAW_CHECKSUM="$(sha256sum "$RAW_FILE" | awk '{print $1}')"

  cat > "$IMAGE_FILE" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256" role="img" aria-label="Generated ${DISPLAY_NAME} badge">
  <rect width="256" height="256" rx="28" fill="${PRIMARY_COLOR}"/>
  <circle cx="128" cy="104" r="58" fill="${SECONDARY_COLOR}" stroke="#2b2b2b" stroke-width="8"/>
  <circle cx="106" cy="94" r="8" fill="#2b2b2b"/>
  <circle cx="150" cy="94" r="8" fill="#2b2b2b"/>
  <circle cx="88" cy="120" r="13" fill="#ef5350"/>
  <circle cx="168" cy="120" r="13" fill="#ef5350"/>
  <path d="M112 126 Q128 140 144 126" fill="none" stroke="#2b2b2b" stroke-width="7" stroke-linecap="round"/>
  <text x="128" y="196" font-family="Arial, sans-serif" font-size="24" font-weight="700" text-anchor="middle" fill="#2b2b2b">${DISPLAY_NAME}</text>
  <text x="128" y="224" font-family="Arial, sans-serif" font-size="20" font-weight="700" text-anchor="middle" fill="#2b2b2b">#${POKEMON_ID}</text>
</svg>
SVG

  IMAGE_SIZE="$(wc -c < "$IMAGE_FILE" | tr -d ' ')"
  IMAGE_CHECKSUM="$(sha256sum "$IMAGE_FILE" | awk '{print $1}')"

  REPORT_ROWS+=$'\n'"${POKEMON_ID},${POKEMON_NAME},${RAW_BUCKET},${RAW_KEY},${RAW_NAME},raw_json,${RAW_SIZE},${RAW_CHECKSUM},success,${TS}"
  REPORT_ROWS+=$'\n'"${POKEMON_ID},${POKEMON_NAME},${IMAGE_BUCKET},${IMAGE_KEY},${IMAGE_NAME},sprite,${IMAGE_SIZE},${IMAGE_CHECKSUM},success,${TS}"

  UPLOAD_COMMAND+=" && mc cp '/workspace/data/generated/raw/${RAW_NAME}' 'local/${RAW_BUCKET}/${RAW_KEY}'"
  UPLOAD_COMMAND+=" && mc cp '/workspace/data/generated/raw/${IMAGE_NAME}' 'local/${IMAGE_BUCKET}/${IMAGE_KEY}'"

  append_sql_value \
    "$POKEMON_ID" \
    "$RAW_BUCKET" \
    "$RAW_KEY" \
    "$RAW_NAME" \
    "raw_json" \
    "application/json" \
    "$RAW_SIZE" \
    "$RAW_CHECKSUM" \
    "demo-script:local-pokeapi-shape" \
    "'https://pokeapi.co/api/v2/pokemon/${POKEMON_NAME}'" \
    "{\"demo\":true,\"types\":${TYPES_JSON},\"retention\":\"raw immutable object\"}"

  append_sql_value \
    "$POKEMON_ID" \
    "$IMAGE_BUCKET" \
    "$IMAGE_KEY" \
    "$IMAGE_NAME" \
    "sprite" \
    "image/svg+xml" \
    "$IMAGE_SIZE" \
    "$IMAGE_CHECKSUM" \
    "demo-script:generated-svg-badge" \
    "NULL" \
    "{\"demo\":true,\"asset_type\":\"generated_badge\",\"primary_color\":\"${PRIMARY_COLOR}\"}"
done

printf '%s\n' "$REPORT_ROWS" > "$REPORT_FILE"
REPORT_SIZE="$(wc -c < "$REPORT_FILE" | tr -d ' ')"
REPORT_CHECKSUM="$(sha256sum "$REPORT_FILE" | awk '{print $1}')"

UPLOAD_COMMAND+=" && mc cp '/workspace/data/generated/reports/${REPORT_NAME}' 'local/${REPORT_BUCKET}/${REPORT_KEY}'"
UPLOAD_COMMAND+=" && mc ls 'local/${RAW_BUCKET}/pokeapi/pokemon/' && mc ls 'local/${IMAGE_BUCKET}/generated/badges/' && mc ls 'local/${REPORT_BUCKET}/ingestion/'"

append_sql_value \
  "25" \
  "$REPORT_BUCKET" \
  "$REPORT_KEY" \
  "$REPORT_NAME" \
  "report_csv" \
  "text/csv" \
  "$REPORT_SIZE" \
  "$REPORT_CHECKSUM" \
  "demo-script:multi-pokemon-ingestion-report" \
  "NULL" \
  "{\"demo\":true,\"report_type\":\"multi_pokemon_ingestion_summary\",\"pokemon_count\":${#POKEMON_ROWS[@]}}"

echo "Starting Docker services..."
"${COMPOSE[@]}" up -d postgres minio minio-init n8n

echo "Waiting for PostgreSQL..."
until "${COMPOSE[@]}" exec -T postgres pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1; do
  sleep 2
done

echo "Uploading objects to MinIO..."
"${COMPOSE[@]}" run --rm -T minio-client "$UPLOAD_COMMAND"

echo "Writing metadata and ingestion logs to PostgreSQL..."
"${COMPOSE[@]}" exec -T postgres psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<SQL
WITH candidate_files (
    pokemon_id,
    bucket_name,
    object_key,
    file_name,
    file_type,
    mime_type,
    size_bytes,
    checksum_sha256,
    source,
    source_url,
    metadata_json
) AS (
    VALUES${SQL_VALUES}
),
upsert_files AS (
    INSERT INTO pokemon_files (
        pokemon_id,
        bucket_name,
        object_key,
        file_name,
        file_type,
        mime_type,
        size_bytes,
        checksum_sha256,
        source,
        source_url,
        metadata_json
    )
    SELECT
        pokemon_id,
        bucket_name,
        object_key,
        file_name,
        file_type::pokemon_file_type,
        mime_type,
        size_bytes,
        checksum_sha256,
        source,
        source_url,
        metadata_json
    FROM candidate_files
    ON CONFLICT (bucket_name, object_key) DO UPDATE
    SET
        size_bytes = EXCLUDED.size_bytes,
        checksum_sha256 = EXCLUDED.checksum_sha256,
        source = EXCLUDED.source,
        source_url = EXCLUDED.source_url,
        metadata_json = EXCLUDED.metadata_json,
        ingested_at = now()
    RETURNING file_id, pokemon_id, bucket_name, object_key, file_name, file_type, size_bytes, checksum_sha256
)
INSERT INTO file_ingestion_log (
    file_id,
    pokemon_id,
    file_name,
    bucket_name,
    object_key,
    source,
    status,
    message,
    size_bytes,
    checksum_sha256,
    workflow_run_id
)
SELECT
    file_id,
    pokemon_id,
    file_name,
    bucket_name,
    object_key,
    'demo-script',
    'success',
    CASE file_type
        WHEN 'raw_json' THEN 'Raw PokeAPI-shaped JSON stored in MinIO and catalogued in PostgreSQL'
        WHEN 'sprite' THEN 'Generated SVG badge stored in MinIO and catalogued in PostgreSQL'
        WHEN 'report_csv' THEN 'CSV report stored in MinIO and catalogued in PostgreSQL'
        ELSE 'Object stored in MinIO and catalogued in PostgreSQL'
    END,
    size_bytes,
    checksum_sha256,
    '${TS}'
FROM upsert_files;
SQL

echo "Proof: object catalog"
"${COMPOSE[@]}" exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT pokemon_id, pokemon_name, bucket_name, object_key, file_type, size_bytes, left(checksum_sha256, 12) AS checksum_prefix, internal_url FROM pokemon_file_catalog ORDER BY ingested_at DESC LIMIT 15;"

echo "Proof: ingestion log"
"${COMPOSE[@]}" exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT log_id, pokemon_id, bucket_name, file_name, status, processed_at, workflow_run_id FROM file_ingestion_log ORDER BY log_id DESC LIMIT 15;"
