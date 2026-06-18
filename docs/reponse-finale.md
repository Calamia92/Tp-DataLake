# Réponse rédigée

L'architecture obtenue se rapproche davantage d'un Data Lake / Lakehouse car elle sépare le stockage des fichiers et le catalogue relationnel.
MinIO apporte une vraie couche de stockage objet : il peut conserver des JSON bruts, images, rapports ou fichiers d'erreurs sans les transformer immédiatement en lignes SQL.
La conservation du brut est utile car elle permet de rejouer une ingestion, de corriger un traitement ou de comparer les données transformées avec la source d'origine.
La base PostgreSQL ne stocke donc pas forcément le fichier lui-même, mais ses métadonnées : bucket, clé objet, type, taille, checksum, source et lien avec le Pokémon.
Cette séparation évite d'alourdir la base avec des fichiers binaires ou semi-structurés qui sont mieux adaptés à un stockage objet.
PostgreSQL garde son rôle fort : indexer, relier les fichiers aux Pokémon, tracer les traitements et rendre les recherches fiables.
MinIO garde son rôle de zone durable pour les données brutes et les artefacts produits par les workflows.
L'ensemble est plus riche qu'une simple base relationnelle car il combine données structurées, fichiers bruts, traçabilité d'ingestion et organisation par zones de stockage.
On obtient ainsi une architecture plus évolutive, où de nouveaux traitements peuvent consommer les objets MinIO tout en s'appuyant sur le catalogue SQL.
