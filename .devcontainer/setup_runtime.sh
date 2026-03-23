#!/bin/bash
set -e

echo "============================================"
echo "  Oracle Agent Memory Workshop - Starting"
echo "============================================"

echo ""
echo "[1/3] Starting Oracle AI Database..."
docker compose -f /workspace/.devcontainer/docker-compose.yml up -d oracle 2>/dev/null

echo ""
echo "[2/3] Waiting for Oracle to be ready..."
for i in $(seq 1 20); do
  python3 -c "
import oracledb, sys
try:
    c = oracledb.connect(user='VECTOR', password='VectorPwd_2025', dsn='localhost:1521/FREEPDB1')
    c.close()
    sys.exit(0)
except:
    sys.exit(1)
" && echo "  Oracle is up after ${i}x attempts." && break \
  || { [ $i -lt 20 ] && printf "  Waiting... (%ds)\r" $((i * 10)) && sleep 10; }
done

echo ""
echo "[3/3] Configuring vector memory pool and restarting Oracle..."
docker exec oracle-free sqlplus -s sys/OraclePwd_2025@localhost:1521/FREE as sysdba << 'SQLEOF'
ALTER SYSTEM SET vector_memory_size = 1G SCOPE=SPFILE;
SHUTDOWN IMMEDIATE;
STARTUP;
EXIT;
SQLEOF

echo "  Waiting for Oracle to come back online..."
for i in $(seq 1 12); do
  python3 -c "
import oracledb, sys
try:
    c = oracledb.connect(user='VECTOR', password='VectorPwd_2025', dsn='localhost:1521/FREEPDB1')
    print(f'  Ready. Oracle version: {c.version}')
    c.close()
    sys.exit(0)
except:
    sys.exit(1)
" && break \
  || { [ $i -lt 12 ] && printf "  Waiting... (%ds)\r" $((i * 10)) && sleep 10; }
done

echo ""
echo "============================================"
echo "  Workshop is ready!"
echo ""
echo "  1. Open:   workshop/notebook_student.ipynb"
echo "  2. Kernel: Oracle Agent Memory Workshop"
echo "  3. Guides: docs/part-1-oracle-setup.md"
echo "============================================"
