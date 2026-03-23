#!/bin/bash
set -e

echo "============================================"
echo "  Oracle Agent Memory Workshop - Build"
echo "============================================"

echo ""
echo "[1/2] Installing Python dependencies..."
pip install -q --no-cache-dir \
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
echo "[2/2] Registering Jupyter kernel..."
python -m ipykernel install --user --name workshop --display-name "Oracle Agent Memory Workshop"

echo ""
echo "Build complete. Oracle will start when the Codespace opens."
echo "============================================"
