# dockerfile-lsp

Dockerfile language server plugin for Claude Code.

## Supported Extensions

`.dockerfile`

> **Note:** Bare `Dockerfile` files without an extension are not covered — only
> `.dockerfile`-suffixed files get LSP. This is a limitation of the
> `extensionToLanguage` mapping.

## Binary Required

```bash
npm install -g dockerfile-language-server-nodejs
```

Installs as `docker-langserver`. Already installed in the container image.

## Install Plugin

```
/plugin install /claude-here/plugins/dockerfile-lsp
```
