#!/bin/bash
set -e

echo "============================================"
echo "  Oracle Agent Memory Workshop - Setup"
echo "============================================"

echo ""
echo "[1/4] Installing Python dependencies..."
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
  matplotlib \
  tiktoken \
  pydantic

echo ""
echo "[2/4] Registering Jupyter kernel..."
python -m ipykernel install --user --name workshop --display-name "Oracle Agent Memory Workshop"

echo ""
echo "[3/4] Verifying Oracle connectivity (with retries)..."
for i in 1 2 3 4 5; do
  python3 -c "
import oracledb
try:
    c = oracledb.connect(user='VECTOR', password='VectorPwd_2025', dsn='oracle:1521/FREEPDB1')
    print('Oracle AI Database 23ai is ready. Version:', c.version)
    c.close()
    exit(0)
except Exception as e:
    exit(1)
" && break || echo "  Attempt $i/5 — Oracle not ready yet, waiting 20s..." && sleep 20
done

echo ""
echo "[4/4] Setup complete!"
echo ""
echo "============================================"
echo "  Getting started:"
echo "  1. Open workshop/notebook_student.ipynb"
echo "  2. Select kernel: Oracle Agent Memory Workshop"
echo "  3. Follow the companion guide in docs/"
echo "============================================"
