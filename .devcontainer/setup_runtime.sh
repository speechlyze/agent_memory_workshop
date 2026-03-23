#!/bin/bash

echo "============================================"
echo "  Oracle Agent Memory Workshop - Starting"
echo "============================================"

# Guard: ensure oracledb is installed regardless of prebuild state
python3 -c "import oracledb" > /dev/null 2>&1 || {
  echo ""
  echo "oracledb not found — installing now..."
  pip install -q oracledb
}

# Wait for Docker daemon
echo ""
echo "[1/3] Waiting for Docker daemon..."
for i in $(seq 1 15); do
  docker info > /dev/null 2>&1 && echo "  Docker is ready." && break \
    || { [ $i -lt 15 ] && echo "  Waiting... (attempt $i/15)" && sleep 3; }
done

# Start Oracle container
echo ""
echo "[2/3] Starting Oracle AI Database..."
docker compose -f .devcontainer/docker-compose.yml up -d oracle 2>/dev/null
echo "  Container started."

# Wait for Oracle initial boot
echo ""
echo "[3/3] Waiting for Oracle to accept connections (cold start — up to 5 min)..."
ORACLE_UP=0
for i in $(seq 1 30); do
  python3 -c "
import oracledb, sys
try:
    c = oracledb.connect(user='VECTOR', password='VectorPwd_2025', dsn='localhost:1521/FREEPDB1')
    c.close()
    sys.exit(0)
except:
    sys.exit(1)
" && echo "  Oracle is accepting connections." && ORACLE_UP=1 && break \
  || echo "  Attempt $i/30 — waiting 10s..." && sleep 10
done

if [ $ORACLE_UP -eq 0 ]; then
  echo ""
  echo "  ERROR: Oracle did not start after 5 minutes (30 attempts x 10s)."
  echo "  Check logs with: docker logs oracle-free"
  exit 1
fi

# Set vector_memory_size immediately in memory (no restart needed)
echo ""
echo "Setting vector_memory_size = 1G..."
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

cur = conn.cursor()

# Check if already set
cur.execute("SELECT value FROM v$parameter WHERE name = 'vector_memory_size'")
row = cur.fetchone()
current = int(row[0]) if row else 0

if current >= 1073741824:
    print(f"  vector_memory_size already set: {current // (1024**2)}M")
    conn.close()
    sys.exit(0)

# SCOPE=BOTH sets in memory immediately AND persists to SPFILE
# Fall back to SCOPE=MEMORY if BOTH fails
for scope in ["BOTH", "MEMORY"]:
    try:
        cur.execute(f"ALTER SYSTEM SET vector_memory_size = 1G SCOPE={scope}")
        conn.commit()
        print(f"  vector_memory_size = 1G applied (SCOPE={scope})")
        break
    except Exception as e:
        print(f"  SCOPE={scope} failed: {e}")
        if scope == "MEMORY":
            conn.close()
            sys.exit(1)

# Verify
cur.execute("SELECT value FROM v$parameter WHERE name = 'vector_memory_size'")
val = int(cur.fetchone()[0])
conn.close()

if val > 0:
    print(f"  Confirmed: vector_memory_size = {val // (1024**2)}M")
else:
    print("  ERROR: vector_memory_size is still 0")
    sys.exit(1)
PYEOF

if [ $? -ne 0 ]; then
  echo "  ERROR: Failed to set vector_memory_size."
  exit 1
fi

echo ""
echo "============================================"
echo "  Workshop is ready!"
echo ""
echo "  1. Open:   workshop/notebook_student.ipynb"
echo "  2. Kernel: Oracle Agent Memory Workshop"
echo "  3. Guides: docs/part-1-oracle-setup.md"
echo "============================================"
