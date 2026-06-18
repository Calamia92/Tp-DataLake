# Workflow n8n

Fichier importable : `n8n/workflows/pokemon-data-lake-ingestion.json`.

Le workflow suit cette chaîne :

```text
Manual Trigger
  -> Fetch Pikachu From PokeAPI
  -> Prepare Raw JSON Object
  -> Upload Raw JSON To MinIO
  -> Register Metadata In PostgreSQL
```

## Credentials à créer dans n8n

Le fichier JSON s'importe sans credentials attachés. Après l'import, ouvrez les noeuds `Upload Raw JSON To MinIO` et `Register Metadata In PostgreSQL`, puis sélectionnez les credentials créés ci-dessous.

### MinIO Data Lake

Type : AWS / S3.

- Access Key ID : `minioadmin`
- Secret Access Key : `minioadmin123`
- Region : `us-east-1`
- Endpoint : `http://minio:9000`
- Force path-style URLs : activé si l'option existe dans votre version n8n

### Pokemon Lake PostgreSQL

Type : PostgreSQL.

- Host : `postgres`
- Port : `5432`
- Database : `pokemon_lake`
- User : `pokemon`
- Password : `pokemon`
- SSL : désactivé

## Ce que fait le workflow

1. Il lit une réponse JSON brute depuis la PokéAPI pour `pikachu`.
2. Il transforme cette réponse en fichier JSON binaire.
3. Il calcule un `checksum_sha256`, une taille, un nom de fichier et une clé objet.
4. Il envoie le JSON brut dans MinIO, bucket `raw-pokemon`.
5. Il écrit la ligne de catalogue dans `pokemon_files`.
6. Il écrit la trace d'exécution dans `file_ingestion_log`.

Le workflow relie explicitement le fichier au Pokémon `pokemon_id = 25`, déjà présent dans la table `pokemon`.
