# Part 5: Web Access with Tavily

## Why Agents Need Web Access

An agent's parametric knowledge (what the LLM was trained on) has a cutoff date and gaps. For tasks involving current events, live data, or domain knowledge not in the knowledge base, the agent needs to reach the web.

Tavily is an AI-optimised search API. Unlike general search APIs that return raw HTML, Tavily returns cleaned, summarised content designed for LLM consumption. This means:

- Less noise in the context window
- Lower token cost per search result
- Content that is already structured for reading, not for web rendering

## Getting Your Tavily API Key

1. Go to [tavily.com](https://tavily.com) and create a free account
2. Copy your API key from the dashboard
3. When the notebook cell prompts `Tavily API Key:`, paste it in

The free tier provides 1,000 searches per month — more than enough for this workshop.

## TODO: Register `web_search` as a Tool

The `@toolbox.register_tool(augment=True)` decorator does two things:

1. Makes the function callable by the agent as a tool
2. With `augment=True`, embeds the function's docstring and stores it in `TOOLBOX_MEMORY` — so the agent can find this tool via semantic search

**The docstring matters.** It is what the agent reads to decide whether to call this tool. Write it as if you are explaining to the agent when and why to use it.

**Complete solution:**

```python
from tavily import TavilyClient
from datetime import datetime

tavily_client = TavilyClient(api_key=os.environ["TAVILY_API_KEY"])

@toolbox.register_tool(augment=True)
def web_search(query: str) -> str:
    """
    Search the internet for current information.

    Use this tool when the user asks about:
    - Recent events or news that may have occurred after your training cutoff
    - Current prices, statistics, or data that changes over time
    - Specific facts you are not confident about
    - Any topic requiring up-to-date information

    Args:
        query: A clear, specific search query string

    Returns:
        Formatted search results with title, URL, and content for each result
    """
    results = tavily_client.search(query=query, max_results=5)
    formatted = []
    for r in results.get("results", []):
        formatted.append(
            f"Title: {r.get('title', '')}\n"
            f"URL: {r.get('url', '')}\n"
            f"Content: {r.get('content', '')}"
        )
    return "\n\n---\n\n".join(formatted)
```

## How Tool Registration Works

After registering the tool, cell 77 demonstrates semantic tool retrieval:

```python
retrieved_tools = memory_manager.read_toolbox("Search the internet")
```

This query searches `TOOLBOX_MEMORY` semantically and returns tools whose descriptions are relevant to the query. The agent uses this same mechanism on each turn to decide which tools to include in its context — instead of being given all tools every time.

This is the **toolbox pattern**: register tools into a vector store, retrieve relevant tools per query. At scale (hundreds of tools), this prevents the tool list from consuming large portions of the context budget.

## Understanding `augment=True`

The `augment` parameter controls whether the tool's description is stored in memory for semantic retrieval. Set it to `True` for tools that should be discoverable by the agent based on task relevance. Set it to `False` for tools that should always be available regardless of the current task (like a `get_time` utility).

## Troubleshooting

**`AuthenticationError` from Tavily** — Your API key is incorrect or was not set. Re-run cell 75 (`set_env_securely`) and paste the key carefully.

**`KeyError: TAVILY_API_KEY`** — Cell 75 did not run. `os.environ["TAVILY_API_KEY"]` will raise if the key is not set. Run cell 75 first.

**Empty results** — Tavily free tier has rate limits. Wait a moment and retry.
