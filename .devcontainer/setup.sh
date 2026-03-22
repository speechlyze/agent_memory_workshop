#!/bin/bash
set -e

echo "============================================"
echo "  Oracle Agent Memory Workshop - Setup"
echo "============================================"

echo ""
echo "[1/5] Installing Python dependencies..."
pip install -qU \
  langchain-oracledb \
  langchain-community \
  langchain-huggingface \
  langchain-openai \
  langchain \
  sentence-transformers \
  oracledb \
  openai \
  tavily-python \
  datasets \
  jupyter \
  ipykernel \
  ipywidgets \
  matplotlib \
  tiktoken \
  pydantic

echo ""
echo "[2/5] Starting Oracle AI Database..."
docker compose -f /workspace/.devcontainer/docker-compose.yml up -d oracle

echo ""
echo "[3/5] Waiting for Oracle initial startup (~90 seconds)..."
for i in $(seq 1 15); do
  python3 -c "
import oracledb
try:
    c = oracledb.connect(user='VECTOR', password='VectorPwd_2025', dsn='localhost:1521/FREEPDB1')
    c.close()
    exit(0)
except Exception:
    exit(1)
" && echo "  Oracle is up." && break || echo "  Attempt $i/15 — waiting 15s..." && sleep 15
done

echo ""
echo "[4/5] Configuring vector memory pool and restarting Oracle..."
docker exec oracle-free sqlplus -s sys/OraclePwd_2025@localhost:1521/FREE as sysdba << 'SQLEOF'
ALTER SYSTEM SET vector_memory_size = 1G SCOPE=SPFILE;
SHUTDOWN IMMEDIATE;
STARTUP;
EXIT;
SQLEOF

echo "  Waiting for Oracle to restart..."
sleep 30
for i in $(seq 1 10); do
  python3 -c "
import oracledb
try:
    c = oracledb.connect(user='VECTOR', password='VectorPwd_2025', dsn='localhost:1521/FREEPDB1')
    print('Oracle AI Database is ready. Version:', c.version)
    c.close()
    exit(0)
except Exception:
    exit(1)
" && break || echo "  Attempt $i/10 — waiting 15s..." && sleep 15
done

echo ""
echo "[5/5] Setup complete!"
echo ""
echo "============================================"
echo "  Getting started:"
echo "  1. Open:          workshop/notebook_student.ipynb"
echo "  2. Select kernel: Python 3"
echo "  3. Follow the companion guide in docs/"
echo "============================================"
