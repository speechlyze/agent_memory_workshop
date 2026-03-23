#!/bin/bash

echo "============================================"
echo "  Oracle Agent Memory Workshop - Starting"
echo "============================================"

# --- Guard: ensure oracledb is installed regardless of prebuild state ---
python3 -c "import oracledb" > /dev/null 2>&1 || {
  echo ""
  echo "[0/4] oracledb not found — installing now..."
  pip install -q oracledb
}

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
  echo "  ERROR: Oracle did not start. Run: docker logs oracle-free"
  exit 1
fi

# --- Step 4: Set vector_memory_size via Python SYSDBA and restart ---
echo ""
echo "[4/4] Setting vector memory pool (1G) and restarting Oracle..."
python3 << 'PYEOF'
import oracledb, sys

try:
    conn = oracledb.connect(
        user="sys",
        password="OraclePwd_2025",
        dsn="localhost:1521/FREE",
        mode=oracledb.SYSDBA
    )
    print("  Connected as SYSDBA to CDB root.")
except Exception as e:
    print(f"  ERROR: Could not connect as SYSDBA: {e}")
    sys.exit(1)

try:
    conn.cursor().execute("ALTER SYSTEM SET vector_memory_size = 1G SCOPE=SPFILE")
    conn.commit()
    print("  vector_memory_size = 1G written to SPFILE.")
except Exception as e:
    print(f"  ERROR setting vector_memory_size: {e}")
    conn.close()
    sys.exit(1)

conn.close()
PYEOF

# Check if Python step succeeded
if [ $? -ne 0 ]; then
  echo "  ERROR: Failed to set vector_memory_size. Aborting restart."
  exit 1
fi

# Restart Oracle container to apply SPFILE change
echo "  Restarting Oracle container to apply SPFILE..."
docker restart oracle-free

# Wait for Oracle to come back and verify
echo "  Waiting for Oracle to come back online..."
ORACLE_READY=0
for i in $(seq 1 15); do
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
        mb = val // (1024**2)
        print(f'  vector_memory_size confirmed: {mb}M')
        sys.exit(0)
    else:
        print('  WARNING: vector_memory_size is still 0.')
        sys.exit(2)
except Exception as e:
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
    echo "  Attempt $i/15 — waiting 10s..."
    sleep 10
  fi
done

if [ $ORACLE_READY -eq 0 ]; then
  echo ""
  echo "  ============================================"
  echo "  WARNING: vector_memory_size not confirmed."
  echo "  If HNSW index creation fails, run manually:"
  echo ""
  echo "  python3 -c \""
  echo "  import oracledb"
  echo "  conn = oracledb.connect(user='sys', password='OraclePwd_2025', dsn='localhost:1521/FREE', mode=oracledb.SYSDBA)"
  echo "  conn.cursor().execute('ALTER SYSTEM SET vector_memory_size = 1G SCOPE=SPFILE')"
  echo "  conn.commit(); conn.close()\""
  echo "  docker restart oracle-free"
  echo "  ============================================"
fi

echo ""
echo "============================================"
echo "  Workshop is ready!"
echo ""
echo "  1. Open:   workshop/notebook_student.ipynb"
echo "  2. Kernel: Oracle Agent Memory Workshop"
echo "  3. Guides: docs/part-1-oracle-setup.md"
echo "============================================"
