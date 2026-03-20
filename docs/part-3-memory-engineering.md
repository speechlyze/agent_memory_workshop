# Part 3: Memory Engineering and Agent Memory

## What Is Agent Memory?

An LLM has no persistent state between calls. Every inference starts from scratch. Agent memory is the infrastructure that gives agents the ability to remember across turns, sessions, and tasks.

The key insight is that different types of information need different storage and retrieval strategies:

| Memory Type | What It Stores | Storage | Retrieval |
|---|---|---|---|
| **Conversational** | Chat history per thread | SQL table | Exact, ordered by time |
| **Knowledge base** | Documents and facts | Vector table | Semantic similarity |
| **Workflow** | Procedural steps and patterns | Vector table | Semantic similarity |
| **Toolbox** | Available tools and descriptions | Vector table | Semantic similarity |
| **Entity** | Named entities and relationships | Vector table | Semantic similarity |
| **Summary** | Compressed context windows | Vector table | Semantic similarity |
| **Tool log** | Raw tool call outputs | SQL table | Exact, by tool call ID |

**Conversational and tool log memory use plain SQL tables** because you always need the exact, ordered history — there is no fuzzy retrieval, you need every message in sequence.

**All semantic memory types use vector-enabled tables** because you need relevance-ranked retrieval — you never retrieve the entire knowledge base, only what is relevant to the current query.

## TODO: `create_conversational_history_table`

This function creates the SQL table that stores chat history. Each row is one message turn.

**Why `SYS_GUID()`?** Oracle's built-in UUID generator. It creates a globally unique ID for each row without requiring a sequence or application-side ID generation.

**Why `TIMESTAMP WITH TIME ZONE`?** Agents may run across time zones. Storing timezone-aware timestamps avoids ambiguity when ordering or filtering by time.

**Complete solution:**

```python
def create_conversational_history_table(conn, table_name: str = "CONVERSATIONAL_MEMORY"):
    with conn.cursor() as cur:
        try:
            cur.execute(f"DROP TABLE {table_name}")
        except:
            pass  # Table does not exist yet — that is fine

        cur.execute(f"""
            CREATE TABLE {table_name} (
                id          VARCHAR2(100) DEFAULT SYS_GUID() PRIMARY KEY,
                thread_id   VARCHAR2(100) NOT NULL,
                role        VARCHAR2(20)  NOT NULL,
                content     CLOB,
                created_at  TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP
            )
        """)
    conn.commit()
    print(f"Created table: {table_name}")
    return table_name
```

**Why `role VARCHAR2(20)`?** Stores `"user"`, `"assistant"`, or `"tool"`. 20 characters is sufficient.

**Why `CLOB` for content?** Messages can be long — tool outputs especially. `CLOB` (Character Large Object) stores up to 4GB of text. `VARCHAR2` maxes out at 32KB in Oracle.

## TODO: Initialise the 5 Vector Memory Stores

Each semantic memory type gets its own `OracleVS` instance backed by its own vector-enabled SQL table. This separation gives you:

- Independent indexes per memory type (faster per-type queries)
- Clean schema boundaries (no mixed-type rows in one table)
- The ability to drop and rebuild one memory type without affecting others

**Complete solution:**

```python
knowledge_base_vs = OracleVS(
    client=vector_conn,
    embedding_function=embedding_model,
    table_name=KNOWLEDGE_BASE_TABLE,
    distance_strategy=DistanceStrategy.COSINE,
)

workflow_vs = OracleVS(
    client=vector_conn,
    embedding_function=embedding_model,
    table_name=WORKFLOW_TABLE,
    distance_strategy=DistanceStrategy.COSINE,
)

toolbox_vs = OracleVS(
    client=vector_conn,
    embedding_function=embedding_model,
    table_name=TOOLBOX_TABLE,
    distance_strategy=DistanceStrategy.COSINE,
)

entity_vs = OracleVS(
    client=vector_conn,
    embedding_function=embedding_model,
    table_name=ENTITY_TABLE,
    distance_strategy=DistanceStrategy.COSINE,
)

summary_vs = OracleVS(
    client=vector_conn,
    embedding_function=embedding_model,
    table_name=SUMMARY_TABLE,
    distance_strategy=DistanceStrategy.COSINE,
)
```

## The MemoryManager Class (Pre-built — Read Carefully)

Cell 58 contains the `MemoryManager` class. This is provided complete — you do not need to modify it. But read through it, because understanding how it works is central to the workshop.

Key methods to understand:

**`write_conversation(thread_id, role, content)`** — Inserts a row into `CONVERSATIONAL_MEMORY`. Called programmatically by the agent harness on every turn.

**`read_conversation(thread_id, limit)`** — Retrieves the last N turns for a thread. Returns them in chronological order so the LLM sees a coherent conversation.

**`write_knowledge(text, metadata)`** — Embeds text and inserts into `SEMANTIC_MEMORY`. Used to load domain knowledge the agent can retrieve.

**`read_knowledge(query, k)`** — Semantic search over the knowledge base. Returns the k most relevant documents for a query.

**`write_toolbox(tool_name, description, metadata)`** — Embeds a tool description and stores it in `TOOLBOX_MEMORY`. Enables the agent to retrieve only relevant tools for a given task.

**`read_toolbox(query, k)`** — Semantic search over registered tools. This is how the agent selects which tools to use without being given all tools on every call.

## Programmatic vs Agent-Triggered Operations

This is the most important design decision in memory engineering. Read cell 54 carefully.

**Programmatic (always runs, harness controls it):**
- Writing conversation turns after each message
- Reading recent conversation history at the start of each turn
- Writing tool call outputs to the tool log

**Agent-triggered (LLM decides when to call it):**
- Searching the knowledge base
- Retrieving workflow patterns
- Summarising the context window
- Expanding a stored summary

Getting this boundary wrong in either direction causes problems:
- Too much programmatic = LLM context floods with irrelevant tokens every turn
- Too much agent-triggered = important state gets missed because the LLM forgot to retrieve it

## Troubleshooting

**`AttributeError: 'NoneType' has no attribute ...`** — One of your `OracleVS` instances is still `None`. Check that your TODO cell ran successfully and the variables are assigned.

**`ORA-00942: table or view does not exist`** — The conversational memory table was not created. Re-run the `create_conversational_history_table` cell.

**`ORA-01408: such column list already indexed`** — An HNSW index already exists on this table from a prior run. The `safe_create_index` helper handles this. If you see it outside that helper, check the index name for a typo.
