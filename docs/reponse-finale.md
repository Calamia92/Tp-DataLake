# Réponse rédigée

Cette architecture ressemble plus à un Data Lake / Lakehouse parce qu'on ne met pas tout directement dans PostgreSQL.
MinIO sert de stockage objet pour garder les fichiers tels qu'ils sont : JSON bruts, images SVG et rapports CSV.
C'est utile de garder les données brutes, car si un traitement est faux, on peut le relancer à partir du fichier d'origine.
La base de données ne stocke donc pas forcément le contenu complet des fichiers.
Elle garde surtout les informations importantes : nom du fichier, bucket, chemin, type, taille, checksum et Pokémon associé.
PostgreSQL sert aussi à tracer les ingestions grâce à la table de logs avec le statut du traitement.
Cette séparation est plus propre qu'une simple base relationnelle, car les fichiers restent dans un stockage adapté.
La base joue le rôle de catalogue, tandis que MinIO joue le rôle de zone de stockage durable.
On obtient donc une architecture plus complète, capable de gérer à la fois des données structurées et des fichiers bruts.
