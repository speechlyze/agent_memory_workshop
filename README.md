# Oracle Agent Memory Workshop

**Build memory-aware AI agents with Oracle AI Database 23ai, LangChain, and Tavily**

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/YOUR-ORG/agent-memory-workshop)

---

## What You Will Build

A complete agent memory system with all major memory types, a `MemoryManager` abstraction over Oracle AI Database 23ai, context engineering techniques that prevent context window overflow, and a turn-level agent harness — finishing with a before/after comparison that makes the impact of memory engineering visible.

## Workshop Parts

| Part | Topic | Guide |
|---|---|---|
| 1 | Oracle AI Database 23ai setup and connection | [Part 1 Guide](docs/part-1-oracle-setup.md) |
| 2 | Vector search with LangChain OracleVS | [Part 2 Guide](docs/part-2-vector-search.md) |
| 3 | Memory engineering: 6 memory types in Oracle | [Part 3 Guide](docs/part-3-memory-engineering.md) |
| 4 | Context engineering: summarisation and offloading | [Part 4 Guide](docs/part-4-context-engineering.md) |
| 5 | Web access with Tavily | [Part 5 Guide](docs/part-5-web-search.md) |
| 6 | Agent execution and memory vs no-memory comparison | [Part 6 Guide](docs/part-6-agent-execution.md) |

## Getting Started

### Option A: GitHub Codespaces (recommended for the workshop)

1. Click the **Open in GitHub Codespaces** badge above
2. Wait for the environment to build (~3-5 minutes — Oracle AI Database is starting)
3. Open `workshop/notebook_student.ipynb` in the file explorer
4. Select the **Oracle Agent Memory Workshop** kernel from the top-right kernel picker
5. Follow the notebook cells top to bottom, using the part guides in `docs/` when you hit a TODO

You will need:
- A GitHub account (free)
- An OpenAI API key
- A Tavily API key (free at [tavily.com](https://tavily.com))

Oracle AI Database 23ai starts automatically inside the Codespace. No local installation required.

### Option B: Local development

```bash
git clone https://github.com/YOUR-ORG/agent-memory-workshop
cd agent-memory-workshop

# Start Oracle AI Database 23ai
docker compose -f .devcontainer/docker-compose.yml up -d oracle

# Install dependencies
pip install langchain-oracledb==0.2.0 sentence-transformers langchain-openai \
  langchain langchain-community tavily-python datasets oracledb openai \
  jupyter ipykernel matplotlib tiktoken

# Launch Jupyter
jupyter lab workshop/notebook_student.ipynb
```

Wait approximately 2 minutes for Oracle to initialise before running notebook cells.

## Workshop Files

```
agent-memory-workshop/
├── .devcontainer/
│   ├── devcontainer.json     Codespaces configuration
│   ├── docker-compose.yml    Oracle 23ai + workshop container
│   └── setup.sh              Dependency installation and Oracle health check
├── workshop/
│   ├── notebook_student.ipynb   Your working notebook (contains TODO gaps)
│   └── notebook_complete.ipynb  Complete reference (do not open until done)
├── docs/
│   ├── part-1-oracle-setup.md
│   ├── part-2-vector-search.md
│   ├── part-3-memory-engineering.md
│   ├── part-4-context-engineering.md
│   ├── part-5-web-search.md
│   └── part-6-agent-execution.md
└── README.md
```

## Stack

- Oracle AI Database 23ai via `gvenzl/oracle-free:23-slim`
- `langchain-oracledb` — LangChain integration for Oracle vector store
- `sentence-transformers` — local embedding model, no API key needed
- `langchain-openai` — OpenAI LLM integration
- `tavily-python` — web search for agents
- `oracledb` — Python Oracle driver

---

Built for the Oracle AI Developer Experience team.
