FROM node:20

ARG TZ
ENV TZ="$TZ"

ARG CLAUDE_CODE_VERSION=2.1.83

# Install basic development tools
RUN apt-get update && apt-get install -y --no-install-recommends \
  bat \
  build-essential \
  curl \
  dnsutils \
  entr \
  fd-find \
  fzf \
  gh \
  git \
  git-lfs \
  gnupg2 \
  htop \
  jq \
  less \
  libxml2-utils \
  lsof \
  make \
  man-db \
  miller \
  nano \
  ncdu \
  netcat-openbsd \
  pandoc \
  parallel \
  poppler-utils \
  postgresql-client \
  procps \
  python3 \
  python3-pip \
  redis-tools \
  ripgrep \
  shellcheck \
  sqlite3 \
  tree \
  unzip \
  uuid-runtime \
  vim \
  xxd \
  xz-utils \
  zsh \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# fd is packaged as fdfind on Debian; bat is packaged as batcat on Debian; ripgrep is rg on Debian
RUN ln -sf /usr/bin/fdfind /usr/local/bin/fd \
  && ln -sf /usr/bin/batcat /usr/local/bin/bat \
  && ln -sf /usr/bin/rg /usr/local/bin/ripgrep

# Install Python tools globally
RUN pip3 install --no-cache-dir --break-system-packages \
  anthropic \
  bandit \
  bibtexparser \
  csvkit \
  habanero \
  hatch \
  httpie \
  httpx \
  inspect-ai \
  ipywidgets \
  jsonschema \
  lxml \
  mypy \
  notebook \
  openai \
  pandas \
  pre-commit \
  pydantic \
  pylint \
  pytest \
  referencing \
  requests \
  ruff \
  semgrep \
  uv \
  yamllint \
  yq

# Ensure default node user has access to /usr/local/share
RUN mkdir -p /usr/local/share/npm-global && \
  chown -R node:node /usr/local/share/npm-global

ARG USERNAME=node

# Persist bash history.
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  && mkdir /commandhistory \
  && touch /commandhistory/.bash_history \
  && chown -R $USERNAME /commandhistory

# Set `DEVCONTAINER` environment variable to help with orientation
ENV DEVCONTAINER=true

# Create workspace and config directories and set permissions
RUN mkdir -p /workspace /home/node/.claude && \
  chown -R node:node /workspace /home/node/.claude

WORKDIR /workspace

ARG GIT_DELTA_VERSION=0.18.2
ARG GIT_DELTA_SHA256_AMD64="1658c7b61825d411b50734f34016101309e4b6e7f5799944cf8e4ac542cebd7f"
ARG GIT_DELTA_SHA256_ARM64="937781aa7788e1510858743fff6c9a8b4a69fe0a22a7c8a69493e633227939a9"
RUN ARCH=$(dpkg --print-architecture) && \
  if [ "$ARCH" = "amd64" ]; then SHA256="${GIT_DELTA_SHA256_AMD64}"; \
  elif [ "$ARCH" = "arm64" ]; then SHA256="${GIT_DELTA_SHA256_ARM64}"; \
  else echo "ERROR: Unsupported architecture: $ARCH" && exit 1; fi && \
  wget "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" -O git-delta.deb && \
  echo "${SHA256}  git-delta.deb" | sha256sum --check && \
  dpkg -i git-delta.deb && \
  rm git-delta.deb

# mise — runtime version manager (Go, Rust, Ruby, etc. on demand)
# To update: download the binary for each arch, run sha256sum, update ARGs below.
# e.g. wget https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/mise-v${MISE_VERSION}-linux-x64 -O /tmp/mise && sha256sum /tmp/mise
ARG MISE_VERSION=2026.3.13
ARG MISE_SHA256_AMD64="806790b4a71c93d20e027c40ddf38470fa6e26555275b1181a3c2ccc082ef56f"
ARG MISE_SHA256_ARM64="c1f56fd3c44a219bbb7064af240b4d3c3e4697b4d88377b8c52576f9a572627e"
RUN ARCH=$(dpkg --print-architecture) && \
  if [ "$ARCH" = "amd64" ]; then SHA256="${MISE_SHA256_AMD64}"; MISE_ARCH="x64"; \
  elif [ "$ARCH" = "arm64" ]; then SHA256="${MISE_SHA256_ARM64}"; MISE_ARCH="arm64"; \
  else echo "ERROR: Unsupported architecture: $ARCH" && exit 1; fi && \
  wget "https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/mise-v${MISE_VERSION}-linux-${MISE_ARCH}" \
    -O /usr/local/bin/mise && \
  echo "${SHA256}  /usr/local/bin/mise" | sha256sum --check && \
  chmod +x /usr/local/bin/mise

# hadolint — Dockerfile linter
# To update: check https://github.com/hadolint/hadolint/releases and download the .sha256 sidecar files.
ARG HADOLINT_VERSION=2.14.0
ARG HADOLINT_SHA256_AMD64="6bf226944684f56c84dd014e8b979d27425c0148f61b3bd99bcc6f39e9dc5a47"
ARG HADOLINT_SHA256_ARM64="331f1d3511b84a4f1e3d18d52fec284723e4019552f4f47b19322a53ce9a40ed"
RUN ARCH=$(dpkg --print-architecture) && \
  if [ "$ARCH" = "amd64" ]; then SHA256="${HADOLINT_SHA256_AMD64}"; HADOLINT_ARCH="x86_64"; \
  elif [ "$ARCH" = "arm64" ]; then SHA256="${HADOLINT_SHA256_ARM64}"; HADOLINT_ARCH="arm64"; \
  else echo "ERROR: Unsupported architecture: $ARCH" && exit 1; fi && \
  wget "https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-linux-${HADOLINT_ARCH}" \
    -O /usr/local/bin/hadolint && \
  echo "${SHA256}  /usr/local/bin/hadolint" | sha256sum --check && \
  chmod +x /usr/local/bin/hadolint

# gitleaks — secret scanner
# To update: check https://github.com/gitleaks/gitleaks/releases and the checksums.txt file.
ARG GITLEAKS_VERSION=8.30.1
ARG GITLEAKS_SHA256_AMD64="551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb"
ARG GITLEAKS_SHA256_ARM64="e4a487ee7ccd7d3a7f7ec08657610aa3606637dab924210b3aee62570fb4b080"
RUN ARCH=$(dpkg --print-architecture) && \
  if [ "$ARCH" = "amd64" ]; then SHA256="${GITLEAKS_SHA256_AMD64}"; GITLEAKS_ARCH="x64"; \
  elif [ "$ARCH" = "arm64" ]; then SHA256="${GITLEAKS_SHA256_ARM64}"; GITLEAKS_ARCH="arm64"; \
  else echo "ERROR: Unsupported architecture: $ARCH" && exit 1; fi && \
  wget "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_${GITLEAKS_ARCH}.tar.gz" \
    -O /tmp/gitleaks.tar.gz && \
  echo "${SHA256}  /tmp/gitleaks.tar.gz" | sha256sum --check && \
  tar -xzf /tmp/gitleaks.tar.gz -C /usr/local/bin gitleaks && \
  rm /tmp/gitleaks.tar.gz

# trufflehog — secret scanner with verified findings
# To update: check https://github.com/trufflesecurity/trufflehog/releases and the checksums.txt file.
ARG TRUFFLEHOG_VERSION=3.94.0
ARG TRUFFLEHOG_SHA256_AMD64="21a67ab716576fda96d96f6478d8b4da84c7a53b43eb27619faa0c228333dde2"
ARG TRUFFLEHOG_SHA256_ARM64="f3383c04229a5b4b50becfe20901df053411323ec9f7d8f9d65719ecdb9df266"
RUN ARCH=$(dpkg --print-architecture) && \
  if [ "$ARCH" = "amd64" ]; then SHA256="${TRUFFLEHOG_SHA256_AMD64}"; TRUFFLEHOG_ARCH="amd64"; \
  elif [ "$ARCH" = "arm64" ]; then SHA256="${TRUFFLEHOG_SHA256_ARM64}"; TRUFFLEHOG_ARCH="arm64"; \
  else echo "ERROR: Unsupported architecture: $ARCH" && exit 1; fi && \
  wget "https://github.com/trufflesecurity/trufflehog/releases/download/v${TRUFFLEHOG_VERSION}/trufflehog_${TRUFFLEHOG_VERSION}_linux_${TRUFFLEHOG_ARCH}.tar.gz" \
    -O /tmp/trufflehog.tar.gz && \
  echo "${SHA256}  /tmp/trufflehog.tar.gz" | sha256sum --check && \
  tar -xzf /tmp/trufflehog.tar.gz -C /usr/local/bin trufflehog && \
  rm /tmp/trufflehog.tar.gz

# gron — make JSON greppable
# To update: check https://github.com/tomnomnom/gron/releases and recompute sha256sum from the downloaded tgz.
ARG GRON_VERSION=0.7.1
ARG GRON_SHA256_AMD64="ca0335826b02b044fa05d7e951521e45c6ced1c381a73ed5803450088e18bf22"
ARG GRON_SHA256_ARM64="5d1d4764723a0f768d9ddef0685a052f564c8bbf5e475382342faf4224a07d80"
RUN ARCH=$(dpkg --print-architecture) && \
  if [ "$ARCH" = "amd64" ]; then SHA256="${GRON_SHA256_AMD64}"; GRON_ARCH="amd64"; \
  elif [ "$ARCH" = "arm64" ]; then SHA256="${GRON_SHA256_ARM64}"; GRON_ARCH="arm64"; \
  else echo "ERROR: Unsupported architecture: $ARCH" && exit 1; fi && \
  wget "https://github.com/tomnomnom/gron/releases/download/v${GRON_VERSION}/gron-linux-${GRON_ARCH}-${GRON_VERSION}.tgz" \
    -O /tmp/gron.tgz && \
  echo "${SHA256}  /tmp/gron.tgz" | sha256sum --check && \
  tar -xzf /tmp/gron.tgz -C /usr/local/bin gron && \
  rm /tmp/gron.tgz

# eza — modern ls replacement
# To update: check https://github.com/eza-community/eza/releases and the sha256sums in the release body.
# Note: aarch64 musl build is not published; arm64 uses the gnu variant.
ARG EZA_VERSION=0.23.4
ARG EZA_SHA256_AMD64="d231bb3ee33b08c76279b5888845dceb7034d055c42bb9be46dbe0dae39394df"
ARG EZA_SHA256_ARM64="366e8430225f9955c3dc659b452150c169894833ccfef455e01765e265a3edda"
RUN ARCH=$(dpkg --print-architecture) && \
  if [ "$ARCH" = "amd64" ]; then SHA256="${EZA_SHA256_AMD64}"; EZA_ASSET="eza_x86_64-unknown-linux-musl.tar.gz"; \
  elif [ "$ARCH" = "arm64" ]; then SHA256="${EZA_SHA256_ARM64}"; EZA_ASSET="eza_aarch64-unknown-linux-gnu.tar.gz"; \
  else echo "ERROR: Unsupported architecture: $ARCH" && exit 1; fi && \
  wget "https://github.com/eza-community/eza/releases/download/v${EZA_VERSION}/${EZA_ASSET}" \
    -O /tmp/eza.tar.gz && \
  echo "${SHA256}  /tmp/eza.tar.gz" | sha256sum --check && \
  tar -xzf /tmp/eza.tar.gz -C /usr/local/bin ./eza && \
  rm /tmp/eza.tar.gz

# zoxide — smarter cd
# To update: check https://github.com/ajeetdsouza/zoxide/releases and recompute sha256sum from the downloaded tgz.
ARG ZOXIDE_VERSION=0.9.9
ARG ZOXIDE_SHA256_AMD64="4ff057d3c4d957946937274c2b8be7af2a9bbae7f90a1b5e9baaa7cb65a20caa"
ARG ZOXIDE_SHA256_ARM64="96e6ea2e47a71db42cb7ad5a36e9209c8cb3708f8ae00f6945573d0d93315cb0"
RUN ARCH=$(dpkg --print-architecture) && \
  if [ "$ARCH" = "amd64" ]; then SHA256="${ZOXIDE_SHA256_AMD64}"; ZOXIDE_ARCH="x86_64"; \
  elif [ "$ARCH" = "arm64" ]; then SHA256="${ZOXIDE_SHA256_ARM64}"; ZOXIDE_ARCH="aarch64"; \
  else echo "ERROR: Unsupported architecture: $ARCH" && exit 1; fi && \
  wget "https://github.com/ajeetdsouza/zoxide/releases/download/v${ZOXIDE_VERSION}/zoxide-${ZOXIDE_VERSION}-${ZOXIDE_ARCH}-unknown-linux-musl.tar.gz" \
    -O /tmp/zoxide.tar.gz && \
  echo "${SHA256}  /tmp/zoxide.tar.gz" | sha256sum --check && \
  tar -xzf /tmp/zoxide.tar.gz -C /usr/local/bin zoxide && \
  rm /tmp/zoxide.tar.gz

# tokei — code statistics (line counts by language)
# Note: aarch64 musl build is not published; arm64 uses the gnu variant.
# To update: check https://github.com/XAMPPRocky/tokei/releases and recompute sha256sum from the downloaded tgz.
ARG TOKEI_VERSION=12.1.2
ARG TOKEI_SHA256_AMD64="331e77046935d655dce8d97ebb943fcc7e9684586dadf3d197f3df5e760cd31b"
ARG TOKEI_SHA256_ARM64="ef514fd12cfc3ee2d1725e5ecb866ee1123163004879ec285b22f3323389ebe2"
RUN ARCH=$(dpkg --print-architecture) && \
  if [ "$ARCH" = "amd64" ]; then SHA256="${TOKEI_SHA256_AMD64}"; TOKEI_ASSET="tokei-x86_64-unknown-linux-musl.tar.gz"; \
  elif [ "$ARCH" = "arm64" ]; then SHA256="${TOKEI_SHA256_ARM64}"; TOKEI_ASSET="tokei-aarch64-unknown-linux-gnu.tar.gz"; \
  else echo "ERROR: Unsupported architecture: $ARCH" && exit 1; fi && \
  wget "https://github.com/XAMPPRocky/tokei/releases/download/v${TOKEI_VERSION}/${TOKEI_ASSET}" \
    -O /tmp/tokei.tar.gz && \
  echo "${SHA256}  /tmp/tokei.tar.gz" | sha256sum --check && \
  tar -xzf /tmp/tokei.tar.gz -C /usr/local/bin tokei && \
  rm /tmp/tokei.tar.gz

# just — command runner (Justfile)
# To update: check https://github.com/casey/just/releases and the SHA256SUMS file.
ARG JUST_VERSION=1.48.0
ARG JUST_SHA256_AMD64="a62e100de2922519ff3d6128f580837b4c0e197aa61a6fb448f43e50e7dd9b9b"
ARG JUST_SHA256_ARM64="3c28914f0059161bc263c41db0ed3f786866cfb9632d1ee7809f529c8f18835e"
RUN ARCH=$(dpkg --print-architecture) && \
  if [ "$ARCH" = "amd64" ]; then SHA256="${JUST_SHA256_AMD64}"; JUST_ARCH="x86_64-unknown-linux-musl"; \
  elif [ "$ARCH" = "arm64" ]; then SHA256="${JUST_SHA256_ARM64}"; JUST_ARCH="aarch64-unknown-linux-musl"; \
  else echo "ERROR: Unsupported architecture: $ARCH" && exit 1; fi && \
  wget "https://github.com/casey/just/releases/download/${JUST_VERSION}/just-${JUST_VERSION}-${JUST_ARCH}.tar.gz" \
    -O /tmp/just.tar.gz && \
  echo "${SHA256}  /tmp/just.tar.gz" | sha256sum --check && \
  tar -xzf /tmp/just.tar.gz -C /usr/local/bin just && \
  rm /tmp/just.tar.gz

# hyperfine — benchmarking tool
# To update: check https://github.com/sharkdp/hyperfine/releases and recompute sha256sum from the downloaded tgz.
# Note: no official checksums file; checksums computed from downloaded release assets.
ARG HYPERFINE_VERSION=1.20.0
ARG HYPERFINE_SHA256_AMD64="3285ec7959285288137043dd81dce0dde056227018a8277532d9a364b4f03c2b"
ARG HYPERFINE_SHA256_ARM64="90875cb1db7a1d797c311174d061728361e58fc70e3b62262a00635ac3b1997c"
RUN ARCH=$(dpkg --print-architecture) && \
  if [ "$ARCH" = "amd64" ]; then SHA256="${HYPERFINE_SHA256_AMD64}"; HYPERFINE_ASSET="hyperfine-v${HYPERFINE_VERSION}-x86_64-unknown-linux-musl.tar.gz"; \
  elif [ "$ARCH" = "arm64" ]; then SHA256="${HYPERFINE_SHA256_ARM64}"; HYPERFINE_ASSET="hyperfine-v${HYPERFINE_VERSION}-aarch64-unknown-linux-gnu.tar.gz"; \
  else echo "ERROR: Unsupported architecture: $ARCH" && exit 1; fi && \
  wget "https://github.com/sharkdp/hyperfine/releases/download/v${HYPERFINE_VERSION}/${HYPERFINE_ASSET}" \
    -O /tmp/hyperfine.tar.gz && \
  echo "${SHA256}  /tmp/hyperfine.tar.gz" | sha256sum --check && \
  tar -xzf /tmp/hyperfine.tar.gz --strip-components=1 -C /usr/local/bin --wildcards '*/hyperfine' && \
  rm /tmp/hyperfine.tar.gz

# websocat — WebSocket client
# To update: check https://github.com/vi/websocat/releases and recompute sha256sum from the downloaded binary.
# Note: no official checksums file; checksums computed from downloaded release assets.
ARG WEBSOCAT_VERSION=1.14.1
ARG WEBSOCAT_SHA256_AMD64="66f8dd3a0394761556339117f8bb5123bddefd44e087af2a72ec22b0bd08d514"
ARG WEBSOCAT_SHA256_ARM64="711a69576a2ff473fb01a90ffafb571c2ed019e55479d7ae71b12c2eadeb7011"
RUN ARCH=$(dpkg --print-architecture) && \
  if [ "$ARCH" = "amd64" ]; then SHA256="${WEBSOCAT_SHA256_AMD64}"; WEBSOCAT_ARCH="x86_64-unknown-linux-musl"; \
  elif [ "$ARCH" = "arm64" ]; then SHA256="${WEBSOCAT_SHA256_ARM64}"; WEBSOCAT_ARCH="aarch64-unknown-linux-musl"; \
  else echo "ERROR: Unsupported architecture: $ARCH" && exit 1; fi && \
  wget "https://github.com/vi/websocat/releases/download/v${WEBSOCAT_VERSION}/websocat.${WEBSOCAT_ARCH}" \
    -O /usr/local/bin/websocat && \
  echo "${SHA256}  /usr/local/bin/websocat" | sha256sum --check && \
  chmod +x /usr/local/bin/websocat

# watchexec — file watcher and command runner
# To update: check https://github.com/watchexec/watchexec/releases and the SHA256SUMS file.
ARG WATCHEXEC_VERSION=2.5.0
ARG WATCHEXEC_SHA256_AMD64="e8015bffea46d9de5cc7ff061afa2d27593e1a1914b406343ef47bb65f5f0634"
ARG WATCHEXEC_SHA256_ARM64="039bc93a4eb395d96127d0ecb6833d742cb41bf9fe9038bb3d6ca5ae507a196e"
RUN ARCH=$(dpkg --print-architecture) && \
  if [ "$ARCH" = "amd64" ]; then SHA256="${WATCHEXEC_SHA256_AMD64}"; WATCHEXEC_ARCH="x86_64-unknown-linux-musl"; \
  elif [ "$ARCH" = "arm64" ]; then SHA256="${WATCHEXEC_SHA256_ARM64}"; WATCHEXEC_ARCH="aarch64-unknown-linux-musl"; \
  else echo "ERROR: Unsupported architecture: $ARCH" && exit 1; fi && \
  wget "https://github.com/watchexec/watchexec/releases/download/v${WATCHEXEC_VERSION}/watchexec-${WATCHEXEC_VERSION}-${WATCHEXEC_ARCH}.tar.xz" \
    -O /tmp/watchexec.tar.xz && \
  echo "${SHA256}  /tmp/watchexec.tar.xz" | sha256sum --check && \
  tar -xJf /tmp/watchexec.tar.xz --strip-components=1 -C /usr/local/bin --wildcards '*/watchexec' && \
  rm /tmp/watchexec.tar.xz

# bun — JavaScript runtime and bundler
# To update: check https://github.com/oven-sh/bun/releases/latest and SHASUMS256.txt for the new version.
ARG BUN_VERSION=1.3.11
ARG BUN_SHA256_AMD64="8611ba935af886f05a6f38740a15160326c15e5d5d07adef966130b4493607ed"
ARG BUN_SHA256_ARM64="d13944da12a53ecc74bf6a720bd1d04c4555c038dfe422365356a7be47691fdf"
RUN ARCH=$(dpkg --print-architecture) && \
  if [ "$ARCH" = "amd64" ]; then SHA256="${BUN_SHA256_AMD64}"; BUN_ARCH="x64"; \
  elif [ "$ARCH" = "arm64" ]; then SHA256="${BUN_SHA256_ARM64}"; BUN_ARCH="aarch64"; \
  else echo "ERROR: Unsupported architecture: $ARCH" && exit 1; fi && \
  wget "https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/bun-linux-${BUN_ARCH}.zip" \
    -O /tmp/bun.zip && \
  echo "${SHA256}  /tmp/bun.zip" | sha256sum --check && \
  unzip /tmp/bun.zip -d /tmp/bun-extracted && \
  mv /tmp/bun-extracted/bun-linux-${BUN_ARCH}/bun /usr/local/bin/bun && \
  chmod +x /usr/local/bin/bun && \
  rm -rf /tmp/bun.zip /tmp/bun-extracted

# Go — system-wide installation
# To update: check https://go.dev/dl/?mode=json for the latest version and SHA256s.
ARG GO_VERSION=1.26.1
ARG GO_SHA256_AMD64="031f088e5d955bab8657ede27ad4e3bc5b7c1ba281f05f245bcc304f327c987a"
ARG GO_SHA256_ARM64="a290581cfe4fe28ddd737dde3095f3dbeb7f2e4065cab4eae44dfc53b760c2f7"
RUN ARCH=$(dpkg --print-architecture) && \
  if [ "$ARCH" = "amd64" ]; then SHA256="${GO_SHA256_AMD64}"; \
  elif [ "$ARCH" = "arm64" ]; then SHA256="${GO_SHA256_ARM64}"; \
  else echo "ERROR: Unsupported architecture: $ARCH" && exit 1; fi && \
  wget "https://dl.google.com/go/go${GO_VERSION}.linux-${ARCH}.tar.gz" -O /tmp/go.tar.gz && \
  echo "${SHA256}  /tmp/go.tar.gz" | sha256sum --check && \
  tar -C /usr/local -xzf /tmp/go.tar.gz && \
  rm /tmp/go.tar.gz

COPY --chown=node:node gitconfig /home/node/.gitconfig

# Set up non-root user
USER node

# Install global packages
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin:/home/node/.local/share/mise/shims:/usr/local/go/bin:/home/node/go/bin

# Set the default shell to zsh rather than sh
ENV SHELL=/bin/zsh

# Set the default editor and visual
ENV EDITOR=vim
ENV VISUAL=vim

# Default powerline10k theme
ARG ZSH_IN_DOCKER_VERSION=1.2.0
ARG ZSH_IN_DOCKER_SHA256="f74e5b08c295b6c3886654bb63c688e5ea16c58a4209435c4ddbab2c42fe9b41"
RUN wget "https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh" -O /tmp/zsh-in-docker.sh \
  && echo "${ZSH_IN_DOCKER_SHA256}  /tmp/zsh-in-docker.sh" | sha256sum --check \
  && sh /tmp/zsh-in-docker.sh -- \
  -p git \
  -p fzf \
  -a "source /usr/share/doc/fzf/examples/key-bindings.zsh" \
  -a "source /usr/share/doc/fzf/examples/completion.zsh" \
  -a "export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  -x \
  && rm /tmp/zsh-in-docker.sh

# mise shell integration (enables auto-switching on cd)
RUN echo 'eval "$(mise activate zsh)"' >> /home/node/.zshrc \
  && echo 'eval "$(mise activate bash)"' >> /home/node/.bashrc

# zoxide shell integration (enables z/zi commands)
RUN echo 'eval "$(zoxide init zsh)"' >> /home/node/.zshrc \
  && echo 'eval "$(zoxide init bash)"' >> /home/node/.bashrc

# Install Claude
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} pnpm typescript tsx prettier eslint dprint yarn markdownlint-cli pyright

# Proxy configuration — defaults route through the ai_filtering_proxy container.
# Override at runtime with -e HTTP_PROXY=... if needed.
ENV HTTP_PROXY=http://ai_filtering_proxy:3128
ENV HTTPS_PROXY=http://ai_filtering_proxy:3128
ENV http_proxy=http://ai_filtering_proxy:3128
ENV https_proxy=http://ai_filtering_proxy:3128
ENV NO_PROXY=localhost,127.0.0.1
ENV no_proxy=localhost,127.0.0.1

# Build metadata — baked in at build time via --build-arg BUILD_DATE=$(date -u +%Y-%m-%d)
ARG BUILD_DATE
ENV BUILD_DATE=${BUILD_DATE}

# Startup screen
USER root
COPY motd.sh /usr/local/bin/motd.sh
RUN chmod +x /usr/local/bin/motd.sh
USER node
RUN printf '\n# Startup screen\nsource /usr/local/bin/motd.sh\n' >> /home/node/.zshrc \
  && printf '\n# Startup screen\nsource /usr/local/bin/motd.sh\n' >> /home/node/.bashrc
