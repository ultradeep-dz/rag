# Use Python 3.11 slim image as base (compatible with Open WebUI)
FROM python:3.11-slim-bookworm

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Set environment variables
ENV OLLAMA_HOST=0.0.0.0
ENV OLLAMA_MODEL=cryptidbleh/gemma4-claude-sonnet-4.6:latest
ENV WEBUI_PORT=3000
ENV OLLAMA_BASE_URL=http://127.0.0.1:11434

# Install system dependencies required for Ollama and Open WebUI
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    ffmpeg \
    libsm6 \
    libxext6 \
    zstd \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Install Ollama
RUN curl -fsSL https://ollama.com/install.sh | sh

# Install Open WebUI via pip
# Note: Open WebUI requires specific dependencies. 
# We install it directly from pip.
RUN pip install --no-cache-dir open-webui

# Create entrypoint script
COPY <<EOF /entrypoint.sh
#!/bin/bash
set -e

echo "Starting Ollama Server..."
ollama serve &
OLLAMA_PID=$!

# Wait for Ollama to be ready
echo "Waiting for Ollama to be ready..."
until curl -f http://localhost:11434/api/tags > /dev/null 2>&1; do
    sleep 2
done

echo "Ollama is ready. Pulling model: ${OLLAMA_MODEL}..."
ollama pull ${OLLAMA_MODEL} || echo "Failed to pull model. Check model name."

echo "Starting Open WebUI on port ${WEBUI_PORT}..."
exec python3 -m open_webui --host 0.0.0.0 --port ${WEBUI_PORT}
EOF

RUN chmod +x /entrypoint.sh

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

CMD ["/entrypoint.sh"]
