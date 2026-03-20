# Part 2: Vector Search with LangChain OracleVS

## What Is Vector Search?

Traditional SQL search matches exact values: `WHERE title = 'neural networks'`. Vector search matches meaning: given a query, find the documents whose semantic content is most similar — even if they share no keywords with the query.

The process is:

1. Convert text to a numeric vector (embedding) using a language model
2. Store vectors in a vector-enabled SQL table
3. At query time, embed the query and find stored vectors with the smallest distance

Oracle AI Database 23ai handles steps 2 and 3 natively. LangChain's `OracleVS` class handles the Python interface.

## The Embedding Model

The notebook uses `sentence-transformers/paraphrase-mpnet-base-v2`, a 768-dimensional sentence embedding model. It runs locally — no API key required. On first use it downloads ~420MB and caches it.

```python
from langchain_community.embeddings import HuggingFaceEmbeddings

embedding_model = HuggingFaceEmbeddings(
    model_name="sentence-transformers/paraphrase-mpnet-base-v2"
)
```

## TODO: Initialise OracleVS

`OracleVS` is a LangChain abstraction that manages a vector-enabled SQL table in Oracle. When you initialise it, it creates the table if it does not exist and connects the embedding model.

**Complete solution:**

```python
from langchain_oracledb.vectorstores import OracleVS
from langchain_oracledb.vectorstores.oraclevs import create_index
from langchain_community.vectorstores.utils import DistanceStrategy

vector_store = OracleVS(
    client=vector_conn,
    embedding_function=embedding_model,
    table_name="VECTOR_SEARCH_DEMO",
    distance_strategy=DistanceStrategy.COSINE,
)
```

**Why `COSINE` distance?** Cosine distance measures the angle between vectors, ignoring magnitude. It works well for text embeddings because it focuses on directional similarity — two documents about the same topic point in the same direction in embedding space regardless of length.

## The HNSW Index

After creating the store, the notebook creates an HNSW index:

```python
safe_create_index(vector_conn, vector_store, "oravs_hnsw")
```

HNSW (Hierarchical Navigable Small World) is a graph-based approximate nearest-neighbour algorithm. Without it, Oracle scans every vector on every query (exact but slow). With it, queries are approximate but fast — typically milliseconds at millions of vectors.

The `safe_create_index` helper skips index creation if the index already exists, so you can safely re-run cells.

## The Dataset

Part 2 loads 1,000 arXiv research paper abstracts from Hugging Face. Each paper is stored as a LangChain `Document` with:

- `page_content`: title + abstract text
- `metadata`: `arxiv_id`, `primary_subject`, `authors`

## TODO: Basic Similarity Search

**Complete solution:**

```python
query = "Find research papers about planetary exploration mission planning."

results = vector_store.similarity_search(query, k=3)

for i, doc in enumerate(results, start=1):
    print(f"--- Result {i} ---")
    print("Text:", doc.page_content)
    print("Metadata:", doc.metadata)
```

`k=3` returns the 3 most similar documents. The query does not need to match any words in the documents — it finds papers whose *meaning* is closest to the query.

## TODO: Search with Scores

**Complete solution:**

```python
results = vector_store.similarity_search_with_score(query, k=3)

for doc, score in results:
    print("Score:", score)
    print("Text :", doc.page_content)
    print("Meta :", doc.metadata)
    print("------")
```

**Score interpretation:** OracleVS returns cosine distance. The range is 0.0 to 2.0. Lower is better:

| Score | Meaning |
|---|---|
| 0.0 | Identical meaning |
| 0.0 – 0.3 | Highly relevant |
| 0.3 – 0.7 | Related |
| 0.7+ | Weak or no match |

## Filtered Search (Pre-built — Read Only)

Cells 35-38 demonstrate metadata filtering. These are complete in your notebook — read through them to understand how to combine semantic similarity with exact SQL-style filters.

```python
# Filter by exact metadata value
docs = vector_store.similarity_search(
    query,
    k=3,
    filter={"primary_subject": {"$eq": sample_primary_subject}},
)

# Filter by ID list
docs = vector_store.similarity_search(
    query="Explain key themes in this research paper",
    k=5,
    filter={"id": {"$in": [sample_arxiv_id]}},
)
```

This is one of Oracle's key advantages: metadata filtering runs as SQL predicates inside Oracle, not as a post-processing step in Python. It is fast and consistent.

## Troubleshooting

**Embedding model download hangs** — The model downloads on first use over the Codespaces network. If it stalls, interrupt the cell and re-run.

**`ORA-00955: name is already used`** — An index already exists from a previous run. `safe_create_index` handles this automatically. If you see it elsewhere, the relevant table already exists — which is fine.

**Empty search results** — You need to ingest the arXiv dataset (cells 28-29) before querying. Make sure those cells ran successfully.
