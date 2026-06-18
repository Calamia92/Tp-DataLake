SELECT 'CREATE DATABASE n8n'
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_database
    WHERE datname = 'n8n'
)\gexec
