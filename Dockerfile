FROM node:20

ARG TZ
ENV TZ="$TZ"

ARG CLAUDE_CODE_VERSION=2.1.81
ARG DPRINT_VERSION=0.51.1
ARG DPRINT_SHA256_AMD64="674c1f9fcdf8a564c26cc027e080d0c4758a40a566e04a776fc83c875ad51d45"
ARG DPRINT_SHA256_ARM64="05a0df273453f099092967641462951fd26dcad282a564f91cc4ad16ea02d526"

# Install basic development tools
RUN apt-get update && apt-get install -y --no-install-recommends \
  dnsutils \
  fzf \
  gh \
  git \
  gnupg2 \
  jq \
  less \
  man-db \
  nano \
  procps \
  python3 \
  python3-pip \
  unzip \
  vim \
  zsh \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir --break-system-packages --require-hashes -r /tmp/requirements.txt \
  && rm /tmp/requirements.txt

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

RUN ARCH=$(dpkg --print-architecture) && \
  if [ "$ARCH" = "amd64" ]; then DPRINT_ARCH="x86_64-unknown-linux-gnu"; SHA256="${DPRINT_SHA256_AMD64}"; \
  elif [ "$ARCH" = "arm64" ]; then DPRINT_ARCH="aarch64-unknown-linux-gnu"; SHA256="${DPRINT_SHA256_ARM64}"; \
  else echo "ERROR: Unsupported architecture: $ARCH" && exit 1; fi && \
  curl -fsSL "https://github.com/dprint/dprint/releases/download/${DPRINT_VERSION}/dprint-${DPRINT_ARCH}.zip" -o /tmp/dprint.zip \
    && echo "${SHA256}  /tmp/dprint.zip" | sha256sum --check \
    && unzip /tmp/dprint.zip -d /usr/local/bin \
    && chmod +x /usr/local/bin/dprint \
    && rm -rf /tmp/dprint.zip


# Set up non-root user
USER node

# Install global packages
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin

# Set the default shell to zsh rather than sh
ENV SHELL=/bin/zsh

# Set the default editor and visual
ENV EDITOR=nano
ENV VISUAL=nano

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

# Install Claude
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

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
