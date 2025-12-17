# Agent Zero Installer - Linux Mint Edition

Production-hardened installer for Agent Zero AI assistant. Designed for personal use on Linux Mint Cinnamon.

## ⚠️ Security Notice

**NEVER** hardcode API keys in the installer. This script reads keys from **environment variables** only.

## Quick Start

### 1. Set API Keys

**Option A: One-time setup in your shell**
```bash
export OPENAI_API_KEY="sk-..."
export GROQ_API_KEY="gsk_..."
export MISTRAL_API_KEY="..."
export OPENROUTER_API_KEY="sk-or-v1-..."
export ANTHROPIC_API_KEY="sk-ant-..."
```

**Option B: Use a .env file (recommended)**
```bash
# Copy template
cp .env.template .env

# Edit with your keys
nano .env

# Load before running
source .env
```

### 2. Run Installer

```bash
chmod +x install-agent-zero.sh
./install-agent-zero.sh
```

### 3. Access

Open browser: [http://localhost:7860](http://localhost:7860)

## Requirements

- Linux Mint 20+ or Ubuntu 20.04+
- Python 3.10+
- 2GB free disk space
- Internet connection

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `OPENAI_API_KEY` | Yes | - | OpenAI API key |
| `GROQ_API_KEY` | Yes | - | Groq Cloud key |
| `MISTRAL_API_KEY` | Yes | - | Mistral AI key |
| `OPENROUTER_API_KEY` | Yes | - | OpenRouter key |
| `ANTHROPIC_API_KEY` | Yes | - | Anthropic key |
| `AGENT_ZERO_DIR` | No | `~/agent-zero` | Install path |
| `GUI_PORT` | No | `7860` | UI port |
| `API_PORT` | No | `5005` | API port |
| `BIND_ADDR` | No | `127.0.0.1` | Bind address |

## Troubleshooting

### Port in use
```bash
GUI_PORT=8080 ./install-agent-zero.sh
```

### Force recreate virtualenv
```bash
FORCE_RECREATE=true ./install-agent-zero.sh
```

### View logs
```bash
tail -f ~/agent-zero/agent-zero.log
```

### Stop service
```bash
kill $(cat ~/agent-zero/agent-zero.pid)
```

## Security Hardening

For personal use, the installer already:
- Binds to localhost only (`127.0.0.1`)
- Sets `.env` permissions to `600`
- Runs as non-root user
- Uses isolated Python virtualenv

**Additional steps:**
- Add firewall rule: `sudo ufw deny from any to any port 7860`
- Use a secrets manager for API keys
- Never share your `.env` file

## Development

### Run tests
```bash
bash -n install-agent-zero.sh  # Syntax check
shellcheck install-agent-zero.sh  # Linting
```

### Dry run
```bash
# The script is idempotent - safe to re-run
./install-agent-zero.sh  # Will update if already installed
```

## License

Apache 2.0 - See LICENSE file