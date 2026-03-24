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
echo "[1/4] Waiting for Docker daemon..."
for i in $(seq 1 15); do
  docker info > /dev/null 2>&1 && echo "  Docker is ready." && break \
    || { [ $i -lt 15 ] && echo "  Waiting... (attempt $i/15)" && sleep 3; }
done

# Start Oracle container
echo ""
echo "[2/4] Starting Oracle AI Database..."
docker compose -f .devcontainer/docker-compose.yml up -d oracle 2>/dev/null
echo "  Container started."

# Wait for Oracle initial boot
echo ""
echo "[3/4] Waiting for Oracle to accept connections (cold start — up to 5 min)..."
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

# Set vector_memory_size via SPFILE and restart Oracle
# Oracle Free cannot dynamically resize SGA — SCOPE=BOTH/MEMORY set the parameter
# but do NOT actually allocate Vector Memory Area. Only SPFILE + restart works.
echo ""
echo "[4/4] Configuring vector_memory_size = 1G..."
python3 << 'PYEOF'
import oracledb, sys, subprocess, time

def connect_sysdba():
    return oracledb.connect(
        user="sys",
        password="OraclePwd_2025",
        dsn="localhost:1521/FREE",
        mode=oracledb.SYSDBA
    )

def get_vector_memory(conn):
    """Check actual SGA component allocation, not just parameter value."""
    cur = conn.cursor()
    # Check v$sga_dynamic_components for actual allocation
    cur.execute("""
        SELECT current_size FROM v$sga_dynamic_components
        WHERE component = 'Vector Memory Area'
    """)
    row = cur.fetchone()
    return int(row[0]) if row else 0

try:
    conn = connect_sysdba()
    print("  Connected as SYSDBA to CDB root.")
except Exception as e:
    print(f"  ERROR: Could not connect as SYSDBA: {e}")
    sys.exit(1)

# Check if Vector Memory Area is actually allocated in SGA
actual_vma = get_vector_memory(conn)
if actual_vma >= 1073741824:
    print(f"  Vector Memory Area already allocated: {actual_vma // (1024**2)}M")
    conn.close()
    sys.exit(0)

print(f"  Vector Memory Area current size: {actual_vma // (1024**2)}M — needs SPFILE + restart")

# Write to SPFILE (takes effect on restart)
cur = conn.cursor()
try:
    cur.execute("ALTER SYSTEM SET vector_memory_size = 1G SCOPE=SPFILE")
    conn.commit()
    print("  Written vector_memory_size = 1G to SPFILE")
except Exception as e:
    print(f"  ERROR setting SPFILE: {e}")
    conn.close()
    sys.exit(1)

conn.close()

# Restart Oracle container so it reads the SPFILE and allocates SGA memory
print("  Restarting Oracle container to apply SPFILE changes...")
result = subprocess.run(["docker", "restart", "oracle-free"], capture_output=True, text=True)
if result.returncode != 0:
    print(f"  ERROR: docker restart failed: {result.stderr}")
    sys.exit(1)

# Wait for Oracle to come back up after restart
print("  Waiting for Oracle to restart...")
for attempt in range(1, 31):
    time.sleep(10)
    try:
        conn = connect_sysdba()
        actual_vma = get_vector_memory(conn)
        conn.close()
        if actual_vma >= 1073741824:
            print(f"  Confirmed: Vector Memory Area = {actual_vma // (1024**2)}M (allocated in SGA)")
            sys.exit(0)
        else:
            print(f"  Oracle is up but VMA = {actual_vma // (1024**2)}M — waiting...")
    except Exception:
        if attempt % 5 == 0:
            print(f"  Attempt {attempt}/30 — Oracle not ready yet...")

print("  ERROR: Vector Memory Area not allocated after restart")
sys.exit(1)
PYEOF

if [ $? -ne 0 ]; then
  echo "  ERROR: Failed to configure vector_memory_size."
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
