#!/bin/bash

echo "============================================"
echo "  Oracle Agent Memory Workshop - Starting"
echo "============================================"

# --- Guard: ensure oracledb is installed regardless of prebuild state ---
python3 -c "import oracledb" > /dev/null 2>&1 || {
  echo ""
  echo "[0/3] oracledb not found — installing now..."
  pip install -q oracledb
}

# --- Step 1: Wait for Docker daemon ---
echo ""
echo "[1/3] Waiting for Docker daemon..."
for i in $(seq 1 15); do
  docker info > /dev/null 2>&1 && echo "  Docker is ready." && break \
    || { [ $i -lt 15 ] && echo "  Waiting for Docker... (attempt $i/15)" && sleep 3; }
done

# --- Step 2: Start Oracle container ---
echo ""
echo "[2/3] Starting Oracle AI Database..."
docker compose -f .devcontainer/docker-compose.yml up -d oracle 2>/dev/null
echo "  Container started."

# --- Step 3: Wait for Oracle to be ready, then configure vector memory ---
echo ""
echo "[3/3] Waiting for Oracle to accept connections..."
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
  echo "  ERROR: Oracle did not start. Run: docker logs oracle-free"
  exit 1
fi

# Set vector_memory_size and restart Oracle to apply
echo "  Setting vector_memory_size = 1G..."
python3 << 'PYEOF'
import oracledb, sys

try:
    conn = oracledb.connect(
        user="sys",
        password="OraclePwd_2025",
        dsn="localhost:1521/FREE",
        mode=oracledb.SYSDBA
    )
    conn.cursor().execute("ALTER SYSTEM SET vector_memory_size = 1G SCOPE=SPFILE")
    conn.commit()
    conn.close()
    print("  vector_memory_size = 1G written to SPFILE.")
except Exception as e:
    print(f"  ERROR: {e}")
    sys.exit(1)
PYEOF

if [ $? -ne 0 ]; then
  echo "  ERROR: Failed to set vector_memory_size."
  exit 1
fi

echo "  Restarting Oracle to apply SPFILE change..."
docker restart oracle-free

# Wait for Oracle to come back with vector_memory_size active
ORACLE_READY=0
for i in $(seq 1 20); do
  python3 -c "
import oracledb, sys
try:
    conn = oracledb.connect(
        user='sys',
        password='OraclePwd_2025',
        dsn='localhost:1521/FREE',
        mode=oracledb.SYSDBA
    )
    cur = conn.cursor()
    cur.execute(\"SELECT value FROM v\\\$parameter WHERE name = 'vector_memory_size'\")
    row = cur.fetchone()
    val = int(row[0]) if row else 0
    conn.close()
    if val > 0:
        print(f'  vector_memory_size confirmed: {val // (1024**2)}M')
        sys.exit(0)
    else:
        sys.exit(2)
except:
    sys.exit(1)
"
  RC=$?
  if [ $RC -eq 0 ]; then
    ORACLE_READY=1
    break
  elif [ $RC -eq 2 ]; then
    echo "  Oracle up but vector_memory_size still 0 — waiting 10s..."
    sleep 10
  else
    echo "  Attempt $i/20 — waiting 10s..."
    sleep 10
  fi
done

if [ $ORACLE_READY -eq 0 ]; then
  echo ""
  echo "  WARNING: vector_memory_size not confirmed after restart."
  echo "  The notebook may fail on HNSW index creation."
fi

echo ""
echo "============================================"
echo "  Workshop is ready!"
echo ""
echo "  1. Open:   workshop/notebook_student.ipynb"
echo "  2. Kernel: Oracle Agent Memory Workshop"
echo "  3. Guides: docs/part-1-oracle-setup.md"
echo "============================================"
