# Commandes de preuve

## 1. Démarrage des services

```bash
docker compose up -d
docker compose ps
```

Preuve attendue : les services `pokemon-postgres`, `pokemon-minio` et `pokemon-n8n` sont démarrés. Le service `pokemon-minio-init` peut être en statut `exited (0)`, ce qui est normal : il sert seulement à initialiser les buckets.

La console MinIO est exposée sur `http://localhost:9101`. Dans le réseau Docker, les services continuent d'utiliser `http://minio:9000`.

## 2. Buckets MinIO

```bash
docker compose run --rm minio-client "mc alias set local http://minio:9000 minioadmin minioadmin123 >/dev/null && mc ls local"
```

Preuve attendue :

```text
raw-pokemon
pokemon-images
reports
```

## 3. Structure SQL

```bash
docker compose exec -T postgres psql -U pokemon -d pokemon_lake -c "\dt"
docker compose exec -T postgres psql -U pokemon -d pokemon_lake -c "\d pokemon_files"
docker compose exec -T postgres psql -U pokemon -d pokemon_lake -c "\d file_ingestion_log"
```

Preuve attendue : présence des tables `pokemon`, `pokemon_files`, `file_ingestion_log` et de la vue `pokemon_file_catalog`.

## 4. Démonstration complète

```bash
bash scripts/demo_ingest.sh
```

Preuve attendue :

- des objets JSON dans `raw-pokemon/pokeapi/pokemon/`
- des images SVG dans `pokemon-images/generated/badges/`
- un rapport CSV dans `reports/ingestion/`
- au moins une ligne dans `pokemon_files`
- au moins une ligne dans `file_ingestion_log`

## 5. Vérification SQL après ingestion

```bash
docker compose exec -T postgres psql -U pokemon -d pokemon_lake -c "SELECT pokemon_id, pokemon_name, bucket_name, object_key, file_type, size_bytes, internal_url FROM pokemon_file_catalog ORDER BY created_at DESC LIMIT 10;"
docker compose exec -T postgres psql -U pokemon -d pokemon_lake -c "SELECT log_id, pokemon_id, bucket_name, file_name, status, processed_at, workflow_run_id FROM file_ingestion_log ORDER BY log_id DESC LIMIT 10;"
```

## 6. Vérification MinIO après ingestion

```bash
docker compose run --rm minio-client "mc alias set local http://minio:9000 minioadmin minioadmin123 >/dev/null && mc tree local/raw-pokemon && mc tree local/pokemon-images && mc tree local/reports"
```
