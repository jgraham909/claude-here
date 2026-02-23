# Claude Code — Sandboxed Docker Environment

A Docker-based sandbox for running [Claude Code](https://claude.ai/code) with outbound network access restricted via an external proxy container. The Claude container has no direct internet access — all traffic is routed through a separately managed `ai_proxy` container that enforces a domain allowlist.

## Prerequisites

- Docker
- `make`
- A Claude Code account
- The `ai_proxy` container running and attached to a Docker network named `ai_proxy_network` (managed separately — see [Network Architecture](#network-architecture))
- `~/.docker-claude/` directory for persisting Claude config (created automatically on first run if absent)

## Quick Start

```bash
# 1. Ensure the ai_proxy container and ai_proxy_network are running

# 2. Build the image
make docker-build

# 3. Run Claude Code against your current directory
make claude-here
```

Your current directory is mounted into the container at `/<dirname>` and set as the working directory, so Claude Code operates on your local files directly.

`make claude-here` will fail immediately with a clear error if `ai_proxy_network` is not found, preventing the container from starting without network restrictions in place.

## Make Targets

| Target | Description |
|---|---|
| `make docker-build` | Build the `claude-code:latest` image |
| `make claude-here` | Run Claude Code in a container against the current directory |
| `make bash` | Open a bash shell in a fresh container |
| `make bash-exec` | Attach to an already-running container named `quirky_rhodes` |
| `make update-requirements` | Regenerate `requirements.txt` from `requirements.in` (requires `pip-tools`) |

## Network Architecture

This container enforces network restrictions through topology rather than in-container firewall rules:

```
[host]
  └── ai_proxy_network (Docker network, internal only)
        ├── ai_proxy container  ← enforces domain allowlist, has external access
        └── claude container    ← no direct external access, proxy is only egress
```

The Claude container is attached exclusively to `ai_proxy_network` and has no route to the internet other than through the proxy. All outbound HTTP/HTTPS traffic is routed via `HTTP_PROXY`/`HTTPS_PROXY` environment variables pointing to `http://ai_proxy:3128`. Any tool that attempts to open a raw socket to an external address will fail at the network level — there is no route.

The `ai_proxy` container and its allowlist configuration are managed separately and are outside the scope of this repository.

### Overriding the proxy

The proxy URL defaults to `http://ai_proxy:3128` and the network to `ai_proxy_network`. Both can be overridden at runtime without rebuilding:

```bash
make claude-here AI_PROXY_NETWORK=my_network PROXY_URL=http://myproxy:8080
```

## Configuration

Claude config (API keys, settings) is stored on the host at `~/.docker-claude/` and mounted into the container at `/home/node/claude-config`. This persists across container restarts.

Shell history is persisted via a Docker volume at `/commandhistory`.

The timezone can be set at build time:

```bash
docker build --build-arg TZ=America/New_York -t claude-code:latest .
```

## Updating Dependencies

### Claude Code version

The CLI version is pinned via `CLAUDE_CODE_VERSION` in the Dockerfile (currently `2.1.50`). To upgrade:

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

Direct dependencies are listed in `requirements.in`. The fully resolved lock file with SHA-256 hashes for all packages (direct and transitive) is in `requirements.txt`.

To add, remove, or upgrade a Python package:

1. Edit `requirements.in`
2. Regenerate the lock file: `make update-requirements` (requires `pip-tools`: `pip install pip-tools`)
3. Rebuild: `make docker-build`

> **Important — Python version pinning caveat:** `requirements.txt` was generated against **Python 3.11** (the version shipped in Debian bookworm, which is the base for `node:20`). Some packages publish Python-version-specific wheels, so the hashes in the lock file are only guaranteed correct for Python 3.11. If the `node:20` base image ever upgrades to a new Python minor version, `requirements.txt` must be regenerated. Check the Python version in the image with:
> ```bash
> docker run --rm claude-code:latest python3 --version
> ```
> If it no longer reports `3.11.x`, regenerate the lock file as described above.

## Architecture

| File | Purpose |
|---|---|
| `Dockerfile` | Image definition — installs tools, pins all versions and checksums |
| `Makefile` | Convenience wrappers around `docker build` / `docker run` |
| `requirements.in` | Human-maintained list of direct Python dependencies |
| `requirements.txt` | Generated full dependency lock file with SHA-256 hashes — do not edit by hand |
