.PHONY: up down ps demo buckets sql proofs logs

up:
	docker compose up -d

down:
	docker compose down

ps:
	docker compose ps

demo:
	bash scripts/demo_ingest.sh

buckets:
	docker compose run --rm minio-client "mc alias set local http://minio:9000 minioadmin minioadmin123 >/dev/null && mc ls local"

sql:
	docker compose exec -T postgres psql -U pokemon -d pokemon_lake -c "SELECT pokemon_id, pokemon_name, bucket_name, object_key, file_type, size_bytes, internal_url FROM pokemon_file_catalog ORDER BY created_at DESC LIMIT 10;"

proofs:
	cat docs/proof-commands.md

logs:
	docker compose logs --tail=80 postgres minio n8n
