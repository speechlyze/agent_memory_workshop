-- Set vector memory pool for HNSW index support
-- This runs automatically on first container startup via container-entrypoint-initdb.d
ALTER SYSTEM SET vector_memory_size = 1G SCOPE=BOTH;
