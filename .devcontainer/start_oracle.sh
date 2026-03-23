#!/bin/bash

echo "[oracle] Waiting for Docker daemon to be ready..."
for i in $(seq 1 15); do
  docker info > /dev/null 2>&1 && echo "[oracle] Docker is ready." && break \
    || { [ $i -lt 15 ] && sleep 3; }
done

echo "[oracle] Starting Oracle AI Database..."
docker compose -f .devcontainer/docker-compose.yml start oracle 2>/dev/null \
  || docker compose -f .devcontainer/docker-compose.yml up -d oracle

echo "[oracle] Waiting for Oracle to accept connections..."
for i in $(seq 1 20); do
  python3 -c "
import oracledb, sys
try:
    c = oracledb.connect(user='sys', password='OraclePwd_2025', dsn='localhost:1521/FREE', mode=oracledb.SYSDBA)
    c.close()
    sys.exit(0)
except:
    sys.exit(1)
" && break || sleep 10
done

# Ensure vector_memory_size is set (it may have been lost if the container was recreated)
python3 << 'PYEOF'
import oracledb, sys

conn = oracledb.connect(
    user="sys",
    password="OraclePwd_2025",
    dsn="localhost:1521/FREE",
    mode=oracledb.SYSDBA
)
cur = conn.cursor()
cur.execute("SELECT value FROM v$parameter WHERE name = 'vector_memory_size'")
row = cur.fetchone()
val = int(row[0]) if row else 0

if val >= 1073741824:
    print(f"[oracle] vector_memory_size already set: {val // (1024**2)}M")
    conn.close()
    sys.exit(0)
else:
    print("[oracle] vector_memory_size not set — writing to SPFILE and requesting restart...")
    cur.execute("ALTER SYSTEM SET vector_memory_size = 1G SCOPE=SPFILE")
    conn.commit()
    conn.close()
    sys.exit(2)
PYEOF

if [ $? -eq 2 ]; then
  echo "[oracle] Restarting Oracle to apply vector_memory_size..."
  docker restart oracle-free
  echo "[oracle] Waiting for Oracle to come back online..."
  for i in $(seq 1 15); do
    python3 -c "
import oracledb, sys
try:
    conn = oracledb.connect(user='sys', password='OraclePwd_2025', dsn='localhost:1521/FREE', mode=oracledb.SYSDBA)
    cur = conn.cursor()
    cur.execute(\"SELECT value FROM v\\\$parameter WHERE name = 'vector_memory_size'\")
    val = int(cur.fetchone()[0])
    conn.close()
    if val > 0:
        print(f'[oracle] vector_memory_size confirmed: {val // (1024**2)}M')
        sys.exit(0)
    else:
        sys.exit(1)
except:
    sys.exit(1)
" && break || { echo "[oracle] Attempt $i/15 — waiting 10s..."; sleep 10; }
  done
fi

echo "[oracle] Oracle container started."
