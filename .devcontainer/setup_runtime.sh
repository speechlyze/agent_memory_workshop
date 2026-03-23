#!/bin/bash

echo "============================================"
echo "  Oracle Agent Memory Workshop - Starting"
echo "============================================"

# --- Step 1: Wait for Docker daemon ---
echo ""
echo "[1/4] Waiting for Docker daemon..."
for i in $(seq 1 15); do
  docker info > /dev/null 2>&1 && echo "  Docker is ready." && break \
    || { [ $i -lt 15 ] && echo "  Waiting for Docker... (attempt $i/15)" && sleep 3; }
done

# --- Step 2: Start Oracle container ---
echo ""
echo "[2/4] Starting Oracle AI Database..."
docker compose -f .devcontainer/docker-compose.yml up -d oracle 2>/dev/null
echo "  Container started."

# --- Step 3: Wait for Oracle initial boot ---
echo ""
echo "[3/4] Waiting for Oracle to accept connections..."
ORACLE_UP=0
for i in $(seq 1 20); do
  python3 -c "
import oracledb, sys
try:
    c = oracledb.connect(user='VECTOR', password='VectorPwd_2025', dsn='localhost:1521/FREEPDB1')
    c.close()
    sys.exit(0)
except:
    sys.exit(1)
" && echo "  Oracle is accepting connections." && ORACLE_UP=1 && break \
  || echo "  Attempt $i/20 — waiting 10s..." && sleep 10
done

if [ $ORACLE_UP -eq 0 ]; then
  echo "  ERROR: Oracle did not start in time. Run 'docker logs oracle-free' to diagnose."
  exit 1
fi

# --- Step 4: Set vector_memory_size and restart ---
echo ""
echo "[4/4] Setting vector memory pool (1G) and restarting Oracle..."
docker exec oracle-free bash -c "
sqlplus -s / as sysdba << 'SQLEOF'
ALTER SYSTEM SET vector_memory_size = 1G SCOPE=SPFILE;
SHUTDOWN IMMEDIATE;
STARTUP;
EXIT;
SQLEOF
"

echo "  Waiting for Oracle to come back online after restart..."
ORACLE_READY=0
for i in $(seq 1 15); do
  python3 -c "
import oracledb, sys
try:
    c = oracledb.connect(user='VECTOR', password='VectorPwd_2025', dsn='localhost:1521/FREEPDB1')
    # Verify vector_memory_size is actually set
    cur = c.cursor()
    cur.execute(\"SELECT value FROM v\$parameter WHERE name = 'vector_memory_size'\")
    row = cur.fetchone()
    val = int(row[0]) if row else 0
    c.close()
    sys.exit(0 if val > 0 else 2)
except Exception as e:
    sys.exit(1)
" 
  RC=$?
  if [ $RC -eq 0 ]; then
    echo "  Oracle is ready. vector_memory_size confirmed set."
    ORACLE_READY=1
    break
  elif [ $RC -eq 2 ]; then
    echo "  WARNING: Oracle is up but vector_memory_size is still 0. Retrying..."
    sleep 10
  else
    echo "  Attempt $i/15 — waiting 10s..." && sleep 10
  fi
done

if [ $ORACLE_READY -eq 0 ]; then
  echo ""
  echo "  WARNING: vector_memory_size may not be set correctly."
  echo "  Run this manually if HNSW index creation fails:"
  echo ""
  echo "    docker exec oracle-free sqlplus / as sysdba"
  echo "    ALTER SYSTEM SET vector_memory_size = 1G SCOPE=SPFILE;"
  echo "    SHUTDOWN IMMEDIATE;"
  echo "    STARTUP;"
  echo "    EXIT;"
fi

echo ""
echo "============================================"
echo "  Workshop is ready!"
echo ""
echo "  1. Open:   workshop/notebook_student.ipynb"
echo "  2. Kernel: Oracle Agent Memory Workshop"
echo "  3. Guides: docs/part-1-oracle-setup.md"
echo "============================================"
