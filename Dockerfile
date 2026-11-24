FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim
WORKDIR /app

# Requirements first so dependency install layer-caches independently.
COPY pyproject.toml ./
RUN uv venv && uv pip install --python /app/.venv/bin/python "mistralai-agents[koyeb]>=1.1.2,<1.2"

# Then the project itself (the worker loads ./main.py).
COPY . .
ENV PATH="/app/.venv/bin:$PATH"

# The container runs only the worker: `agents deploy` registers the agent.
CMD ["agents", "run-worker"]
