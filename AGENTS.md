## Guidance for AI agents working in this environment.

### User & Permissions

Running as non-root `node` user. `sudo` is not available — do not attempt system-level installs.

### Pre-installed Tools

Do not attempt to reinstall these. Key tools available:

- **Search/files:** `rg`, `fd`, `bat`, `fzf`, `eza`, `gron`, `tokei`, `zoxide`
- **Data:** `jq`, `yq`, `mlr`, `sqlite3`, `pandoc`
- **DB clients:** `psql`, `redis-cli`
- **Security:** `gitleaks`, `trufflehog`, `hadolint`, `shellcheck`
- **Runtimes:** Node 20, Go, Bun, Python 3
- **JS:** `pnpm`, `yarn`, `tsx`, `tsc`, `prettier`, `eslint`, `dprint`
- **Python:** `ruff`, `mypy`, `pylint`, `pytest`, `uv`, `httpie`, `anthropic`, `openai`, `pandas`, `pydantic`

Note: `fd`, `bat`, and `rg` are the correct command names (Debian aliases are symlinked).

### Installing Additional Packages

- **Python:** `uv pip install <pkg>` (non-root safe, session-scoped)
- **Other runtimes** (Ruby, Rust, etc.): `mise install <runtime>`

### Git Identity

`user.name` and `user.email` are not configured. Commits will fail until set. Inform the user if this blocks your work.

### Network

All traffic routes through an `ai_filtering_proxy`. If a request is blocked:
- You cannot resolve this autonomously.
- Inform the user of the blocked domain and ask them to add it to the proxy allowlist or restart the session with `--unfiltered` for unrestricted access.
