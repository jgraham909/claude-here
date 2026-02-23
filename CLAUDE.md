# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Docker-based development container configuration for running Claude Code CLI in a sandboxed environment. Network access is restricted by routing all traffic through an external `ai_proxy` container that enforces a domain allowlist. It is not an application codebase — it consists of configuration files only.

## Build and Run Commands

- `make docker-build` — Build the Docker image (`claude-code:latest`)
- `make claude-here` — Run Claude Code CLI in a container (mounts current directory, requires `ai_proxy_network`)
- `make bash` — Open a bash shell in a new container (requires `ai_proxy_network`)
- `make update-requirements` — Regenerate `requirements.txt` from `requirements.in`

Host-side Claude config is stored at `~/.docker-claude` and mounted into the container at `/home/node/claude-config`.

## Architecture

**Dockerfile**: Based on `node:20`. Installs Claude Code via npm globally, sets up a non-root `node` user, configures zsh with powerlevel10k, and installs dev tools (git, gh, vim, nano, fzf, git-delta, dprint). The `CLAUDE_CODE_VERSION` build arg controls the CLI version. All binary downloads are pinned by version and verified with SHA-256 checksums at build time.

**Makefile**: Wrapper around `docker build` and `docker run`. Containers run as UID 1000:1000 (`node` user), are attached exclusively to `ai_proxy_network`, and have `HTTP_PROXY`/`HTTPS_PROXY` set to route through the proxy. Both targets verify the network exists before starting.

**requirements.in**: Human-maintained list of direct Python dependencies. Edit this to add or upgrade packages.

**requirements.txt**: Generated full dependency lock file with SHA-256 hashes for all packages (direct and transitive). Regenerate with `make update-requirements`. Do not edit by hand.

## Key Details

- The container's working directory is `/workspace`, but `make claude-here` mounts the host CWD to `/<dirname>`
- The container has no direct internet access — the `ai_proxy` container is the only egress path
- Shell history persists via a `/commandhistory` volume
- Python packages are installed with `--require-hashes` against Python 3.11 (Debian bookworm); regenerate `requirements.txt` if the base image Python version changes
