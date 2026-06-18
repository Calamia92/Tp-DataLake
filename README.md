# TP Data Lake Pokémon

Ce projet met en place une mini architecture Data Lake / Lakehouse avec PostgreSQL, MinIO et n8n.

## Architecture

```text
PokéAPI ou fichier généré
        |
        v
      n8n / script de démo
        |
        +--> MinIO : fichiers bruts, images, rapports
        |
        +--> PostgreSQL : catalogue, métadonnées, logs d'ingestion
```

Organisation MinIO retenue : trois buckets séparés.

- `raw-pokemon` : réponses JSON brutes et données sources non transformées
- `pokemon-images` : sprites, images officielles, assets liés aux Pokémon
- `reports` : rapports CSV/JSON, fichiers d'erreurs ou d'anomalies

Ce découpage est plus clair qu'un bucket unique pour le TP : chaque bucket correspond à une zone fonctionnelle et peut avoir ses propres règles de sécurité, de rétention ou de cycle de vie.

## Démarrage

```bash
docker compose up -d
```

Services exposés :

- MinIO API : http://localhost:9100
- MinIO Console : http://localhost:9101
- n8n : http://localhost:5678
- PostgreSQL : `localhost:5432`

Identifiants de démo :

- MinIO : `minioadmin` / `minioadmin123`
- PostgreSQL : `pokemon` / `pokemon`
- Base métier : `pokemon_lake`

## Schéma SQL

Le schéma est initialisé automatiquement par les fichiers dans `postgres/init/`.

Tables principales :

- `pokemon` : petite base Pokémon de référence pour le TP
- `pokemon_files` : catalogue des objets stockés dans MinIO
- `file_ingestion_log` : journal des traitements d'ingestion

La vue `pokemon_file_catalog` joint directement les fichiers aux Pokémon pour faciliter les preuves.

## Workflow n8n

Workflow importable :

```text
n8n/workflows/pokemon-data-lake-ingestion.json
```

Documentation :

```text
docs/n8n-workflow.md
```

Le workflow lit un JSON depuis la PokéAPI, l'envoie dans MinIO, puis enregistre les métadonnées dans PostgreSQL avec le lien vers `pokemon_id = 25`.

## Démonstration automatique

Pour générer un exemple complet sans dépendre d'une connexion externe :

```bash
bash scripts/demo_ingest.sh
```

Le script :

1. démarre les services Docker ;
2. génère un JSON brut de type PokéAPI pour 6 Pokémon de référence ;
3. génère une image SVG de badge pour chaque Pokémon ;
4. génère un rapport CSV global d'ingestion ;
5. envoie les fichiers dans MinIO ;
6. insère les métadonnées dans `pokemon_files` ;
7. insère les traces dans `file_ingestion_log` ;
8. affiche les preuves SQL.

## Preuves à mettre dans le rendu

Toutes les commandes utiles sont dans :

```text
docs/proof-commands.md
```

Les captures d'écran du TP sont à déposer directement à la racine du projet, à côté du `README.md`, pour qu'elles soient faciles à retrouver si l'envoi séparé sur Teams ne fonctionne pas.

Exemples de noms :

```text
screen-01-docker-compose.png
screen-02-minio-buckets.png
screen-03-minio-objects.png
screen-04-postgres-tables.png
screen-05-postgres-metadata.png
screen-06-n8n-workflow.png
```

Réponse rédigée pour la partie D :

```text
docs/reponse-finale.md
```
