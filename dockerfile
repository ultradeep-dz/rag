# Use Ubuntu 22.04 as the base image
FROM ubuntu:22.04

# Prevent interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Set environment variables for Ollama and Open WebUI
# 1. Allow Ollama to listen on all interfaces (required for Docker/Render)
ENV OLLAMA_HOST=0.0.0.0
# 2. Specify the model to pull automatically
# WARNING: Verify this model name exists. If it fails, Ollama won't start serving.
ENV OLLAMA_MODEL=cryptidbleh/gemma4-claude-sonnet-4.6:latest
# 3. Open WebUI configuration
ENV WEBUI_PORT=3000
ENV OLLAMA_BASE_URL=http://127.0.0.1:11434

# Install prerequisites: curl, python, pip, nginx (optional proxy), and utilities
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    python3 \
    python3-pip \
    python3-venv \
    git \
    ffmpeg \
    libsm6 \
    libxext6 \
    && rm -rf /var/lib/apt/lists/*

# Install Ollama
RUN curl -fsSL https://ollama.com/install.sh | sh

# Install Open WebUI
# We use pip to install open-webui directly
RUN pip3 install open-webui

# Create a startup script to handle background processes
# 1. Start Ollama server in the background
# 2. Pull the specified model
# 3. Start Open WebUI
COPY <<EOF /entrypoint.sh
#!/bin/bash
set -e

echo "Starting Ollama Server..."
# Start ollama serve in the background
ollama serve &
OLLAMA_PID=$!

# Wait for Ollama to be ready
echo "Waiting for Ollama to be ready..."
until curl -f http://localhost:11434/api/tags > /dev/null 2>&1; do
    sleep 2
done

echo "Ollama is ready. Pulling model: ${OLLAMA_MODEL}..."
# Pull the model. If it fails, we log error but continue so you can debug via logs
ollama pull ${OLLAMA_MODEL} || echo "Failed to pull model. Check model name."

echo "Starting Open WebUI on port ${WEBUI_PORT}..."
# Start Open WebUI
# --host 0.0.0.0 makes it accessible externally
# --port matches the env var
exec python3 -m open_webui --host 0.0.0.0 --port ${WEBUI_PORT}
EOF

RUN chmod +x /entrypoint.sh

# Expose the Open WebUI port
# Render will map the external port to this internal port
EXPOSE 3000

# Health check (optional but good for Render)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# Run the entrypoint
CMD ["/entrypoint.sh"]
