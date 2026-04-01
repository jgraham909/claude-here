# AI Harness — Sandboxed Docker Environment

A Docker-based sandbox for running AI coding assistants (Claude Code and OpenAI Codex) with outbound network access restricted via an external proxy container. The container has no direct internet access — all traffic is routed through a separately managed `ai_filtering_proxy` container that enforces a domain allowlist.

## Prerequisites

- Docker
- `make`
- A Claude Code account and/or OpenAI API key for Codex
- The `ai_filtering_proxy` container running and attached to a Docker network named `ai_proxy_network_internal` (managed separately — see [Network Architecture](#network-architecture))
- `~/.docker-claude/` directory for persisting AI assistant config (created automatically on first run if absent)

## Quick Start

```bash
# 1. Ensure the ai_filtering_proxy container and ai_proxy_network_internal are running

# 2. Build the image
make docker-build

# 3. Run Claude Code (default)
make claude-here

# Run Codex
make claude-here HARNESS=codex
# or
make codex-here
```

Your current directory is mounted into the container at `/<dirname>` and set as the working directory, so the AI assistant operates on your local files directly.

`make claude-here` will fail immediately with a clear error if `ai_proxy_network_internal` is not found, preventing the container from starting without network restrictions in place.

## Make Targets

| Target | Description |
|---|---|
| `make docker-build` | Build the `claude-code:latest` image |
| `make claude-here` | Run Claude Code in a container (filtered mode) |
| `make claude-here HARNESS=codex` | Run Codex instead of Claude |
| `make codex-here` | Shortcut for running Codex |
| `make bash` | Open a bash shell in a fresh container |

## Network Architecture

This container enforces network restrictions through topology rather than in-container firewall rules:

```
[host]
  └── ai_proxy_network_internal (Docker network, internal only)
        ├── ai_filtering_proxy container  ← enforces domain allowlist, has external access
        └── claude container    ← no direct external access, proxy is only egress
```

The container is attached exclusively to `ai_proxy_network_internal` and has no route to the internet other than through the proxy. All outbound HTTP/HTTPS traffic is routed via `HTTP_PROXY`/`HTTPS_PROXY` environment variables pointing to `http://ai_filtering_proxy:3128`. Any tool that attempts to open a raw socket to an external address will fail at the network level — there is no route.

The `ai_filtering_proxy` container and its allowlist configuration are managed separately and are outside the scope of this repository.

### Overriding the proxy

The proxy URL defaults to `http://ai_filtering_proxy:3128` and the network to `ai_proxy_network_internal`. Both can be overridden at runtime without rebuilding:

```bash
make claude-here AI_PROXY_NETWORK=my_network PROXY_URL=http://myproxy:8080
```

## Configuration

AI assistant config (API keys, settings) is stored on the host at `~/.docker-claude/` and mounted into the container. This persists across container restarts.

Shell history is persisted via a Docker volume at `/commandhistory`.

The timezone can be set at build time:

```bash
docker build --build-arg TZ=America/New_York -t claude-code:latest .
```

## Codex Setup

[OpenAI Codex CLI](https://github.com/openai/codex) is pre-installed and available as `codex` inside the container.

### First-time authentication

Codex stores its auth and config at `~/.codex/` relative to the user's home directory. Inside this container that is `/home/node/.codex/` — **separate from any Codex installation on your host OS** (where it would be at `~/.codex/`). The two never share credentials automatically.

To authenticate for the first time, open a shell in a fresh container and run the normal init flow:

```bash
make bash
# inside the container:
codex
```

Follow the prompts to log in / set your API key. Codex will write its config to `/home/node/.codex/`.

### Persisting auth across container restarts

Codex auth is automatically persisted. `/home/node/.codex/` inside the container is bind-mounted to `~/.docker-claude/codex/` on the host, so credentials survive container restarts just like Claude's own config.

## Updating Dependencies

### Claude Code version

The CLI version is pinned via `CLAUDE_CODE_VERSION` in the Dockerfile (currently `2.1.81`). To upgrade:

1. Update the `ARG CLAUDE_CODE_VERSION=` line in the Dockerfile
2. Rebuild: `make docker-build`

### Binary tools (git-delta, dprint, zsh-in-docker)

Each binary is pinned by version and verified with a SHA-256 checksum at build time. To upgrade:

1. Update the `ARG <TOOL>_VERSION=` line in the Dockerfile
2. Download the new release artifact(s) and compute their hashes:
   ```bash
   sha256sum <downloaded-file>
   ```
3. Update the corresponding `ARG <TOOL>_SHA256_*=` lines with the new hashes
4. Rebuild: `make docker-build`

### Python packages

Python packages are installed globally in the Dockerfile via `pip3 install --break-system-packages`. To add, remove, or upgrade a package, edit the `pip3 install` block in the Dockerfile and rebuild:

```bash
make docker-build
```

## Standalone `ai-here` command

The `ai-here` script in the repo root is a self-contained equivalent of `make claude-here` that works from any directory without needing `make` or the repo on your `PATH`.

### Convenience wrappers

Two convenience wrappers are provided for each harness:

- `claude-here` — launches Claude Code (equivalent to `ai-here --harness claude`)
- `codex-here` — launches Codex (equivalent to `ai-here --harness codex`)

Both wrappers forward all arguments to `ai-here`, so flags like `--unfiltered` work identically.

To install them as user commands:

```bash
mkdir -p ~/.local/bin
ln -s /path/to/repo/claude-here ~/.local/bin/claude-here
ln -s /path/to/repo/codex-here ~/.local/bin/codex-here
```

For system-wide access, you can symlink directly to `/usr/local/bin/`:

```bash
sudo ln -s /path/to/repo/claude-here /usr/local/bin/claude-here
sudo ln -s /path/to/repo/codex-here /usr/local/bin/codex-here
```

Ensure `~/.local/bin` is on your `PATH` (add to `~/.bashrc` / `~/.zshrc` if not already):

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Then from any directory:

```bash
cd ~/some-project
ai-here
```

### Harness selection

Use the `--harness` parameter to choose which AI assistant to run:

```bash
# Run Claude Code (default)
ai-here

# Run Codex
ai-here --harness codex

# Unfiltered mode with Codex
ai-here --harness codex --unfiltered
```

The same environment variable overrides apply as with the Makefile target:

```bash
AI_PROXY_NETWORK=my_network PROXY_URL=http://myproxy:8080 ai-here
```

### Unfiltered mode — direct internet access

Pass `--unfiltered` to bypass the proxy entirely and give the container direct internet access:

```bash
ai-here --unfiltered
```

In this mode the container is attached to the `bridge` network (overridable via `OPEN_NETWORK`) with all proxy environment variables cleared. The startup banner will display a prominent warning indicating the session is unfiltered.

This makes `ai-here --unfiltered` a good research platform — the AI assistant can freely fetch documentation, browse APIs, clone repositories, and reach any external service without the domain allowlist getting in the way.

> **Security note:** The container has no network restrictions in this mode. Avoid using it with sensitive codebases or credentials, and be mindful of what data may leave the container.

## Architecture

| File | Purpose |
|---|---|
| `Dockerfile` | Image definition — installs tools, pins all versions and checksums |
| `Makefile` | Convenience wrappers around `docker build` / `docker run` |
| `claude-here` | Standalone script — run AI assistants from any directory without `make` |
| `motd.sh` | Startup banner displayed when a container opens |
