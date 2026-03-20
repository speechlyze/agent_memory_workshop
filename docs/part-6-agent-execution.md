# Part 6: Agent Execution

## No TODOs — Read and Run

Part 6 contains no incomplete cells. The agent harness is fully implemented. Your job in this part is to:

1. Read through `call_agent()` to understand how all previous parts connect
2. Run the agent and observe its behaviour
3. Run the naive comparison and understand what changes

## The Agent Harness Architecture

`call_agent()` implements a turn-level agent loop. Here is the full flow on each call:

```
1. BUILD CONTEXT (programmatic — always runs)
   ├── Read conversational memory (recent unsummarised turns for this thread)
   ├── Read knowledge base (top-k relevant documents for the current query)
   ├── Read workflow memory (relevant procedural patterns)
   ├── Read entity memory (relevant named entities)
   └── Assemble system prompt with all retrieved context

2. TOOL SELECTION (programmatic)
   └── Retrieve relevant tools from TOOLBOX_MEMORY using the query as a search key
       (semantic retrieval — only tools relevant to this task)

3. LLM CALL
   └── Send assembled context + tool definitions to the model

4. TOOL-CALL LOOP (agent-triggered)
   ├── If the model returns tool_calls:
   │   ├── Execute each tool
   │   ├── Log output to TOOL_LOG (programmatic)
   │   ├── Check context window usage
   │   ├── Offload to summary if usage > 80% (programmatic)
   │   └── Loop back to LLM with tool results
   └── If no tool_calls: proceed to final response

5. WRITE MEMORY (programmatic — always runs)
   ├── Write user message to CONVERSATIONAL_MEMORY
   └── Write assistant response to CONVERSATIONAL_MEMORY

6. RETURN final response
```

## Key Design Decisions to Notice

**Thread isolation:** Each call takes a `thread_id`. All memory reads and writes are scoped to that thread. Two concurrent users with different thread IDs have completely separate memory spaces.

**Iteration cap:** `max_iterations=10` prevents infinite tool-call loops. If the agent has not resolved the task in 10 iterations, it returns whatever it has. Adjust this for complex tasks.

**Context window tracking:** `context_size_history` is a list that persists across calls (it is defined outside `call_agent`). The chart in cell 84 reads from this list to show cumulative context growth.

**Programmatic vs agent-triggered boundary:** Notice that memory writes always happen (programmatic). Memory reads for knowledge, workflow, and entities happen programmatically at the start of each turn. Tool calls happen only when the model decides to invoke them.

## Running the Agent

Cell 83 runs a simple test:

```python
call_agent("What was my first question to you", thread_id="0022")
```

On the first call with thread `"0022"`, there is no prior conversation history — so the agent should say it has not spoken to you before. Call it a second time with the same `thread_id` to see memory working: it will recall the first question.

## The Naive Baseline Comparison

Cell 86 implements `call_agent_naive()`. It is identical to `call_agent()` except it:

- Does not read or write any memory
- Appends every message and tool result to a single growing list
- Makes no attempt to manage context window size

Cell 87 runs both agents through the same sequence of queries on isolated thread IDs.

Cell 88 plots context token growth for both. You should see:
- **Memory-engineered agent:** relatively flat or controlled growth due to summarisation and selective retrieval
- **Naive agent:** continuous upward growth until it would eventually hit the token limit

This chart is the clearest visual argument for why memory engineering matters. Screenshot it — it is good content for the #100DaysOfAgentMemory series.

## Key Takeaways

**Memory is infrastructure, not a feature.** The `MemoryManager` is not an optional add-on — without it the agent cannot function across turns. Oracle AI Database provides the persistence layer that makes this infrastructure reliable, queryable, and scalable.

**Context engineering is the other half.** Storing memory is easy. Deciding what to retrieve, when to retrieve it, and when to compress is where the engineering work lives.

**The database is the right abstraction.** You could implement this with flat files or Redis. But Oracle gives you SQL queries over your memory, ACID consistency, vector search, and a single system of record. For production agents, that matters.

**The toolbox pattern scales.** With 5 tools it feels like overhead. With 50 tools it becomes essential. The toolbox pattern is the foundation for building agents that can operate across large, composable tool libraries.
