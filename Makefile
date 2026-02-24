PROJECT              = claude-code
BUILD_DIR           ?= .
HOST_CLAUDE_CONFIG_DIR = $${HOME}/.docker-claude
CLAUDE_CONFIG_DIR    = /home/node/claude-config
CURRENT_DIR_NAME    := $(notdir $(shell pwd))
AI_PROXY_NETWORK    ?= ai_proxy_network_internal
PROXY_URL           ?= http://ai_filtering_proxy:3128

PROXY_ENV = \
  -e HTTP_PROXY=$(PROXY_URL) \
  -e HTTPS_PROXY=$(PROXY_URL) \
  -e http_proxy=$(PROXY_URL) \
  -e https_proxy=$(PROXY_URL) \
  -e NO_PROXY=localhost,127.0.0.1 \
  -e no_proxy=localhost,127.0.0.1

docker-build:
	@docker build -t $(PROJECT):latest \
		--build-arg BUILD_DATE=$(shell date -u +%Y-%m-%d) \
		-f Dockerfile .

check-network:
	@docker network inspect $(AI_PROXY_NETWORK) >/dev/null 2>&1 || \
		(echo "ERROR: Docker network '$(AI_PROXY_NETWORK)' not found. Is the ai_filtering_proxy container running?" && exit 1)

bash: check-network
	@echo "running bash"
	@docker run -u 1000:1000 --rm -it \
		--network $(AI_PROXY_NETWORK) \
		$(PROXY_ENV) \
		-e "CLAUDE_CONFIG_DIR=$(CLAUDE_CONFIG_DIR)" \
		-v $(HOST_CLAUDE_CONFIG_DIR):$(CLAUDE_CONFIG_DIR) \
		-v $(shell pwd):/app \
		-w /app \
		$(PROJECT) bash


claude-here: check-network
	@echo "running claude"
	@docker run -u 1000:1000 --rm -it \
		--network $(AI_PROXY_NETWORK) \
		$(PROXY_ENV) \
		-e "CLAUDE_CONFIG_DIR=$(CLAUDE_CONFIG_DIR)" \
		-v $(HOST_CLAUDE_CONFIG_DIR):$(CLAUDE_CONFIG_DIR) \
		-v $(shell pwd):/$(CURRENT_DIR_NAME) \
		-w /$(CURRENT_DIR_NAME) \
		$(PROJECT) bash -c '/usr/local/bin/motd.sh && exec claude'

update-requirements:
	pip-compile --generate-hashes --output-file requirements.txt requirements.in
