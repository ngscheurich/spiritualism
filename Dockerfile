FROM alpine:3.24.0

ARG MISE_VERSION=2026.9.18

ENV LANG=C.UTF-8 \
    PATH="/root/.local/bin:${PATH}"

# Install system packages
RUN apk add --no-cache \
    bash curl fd file git jq python3 ripgrep

# Install microsandbox
# RUN curl -fsSL https://install.microsandbox.dev | sh

# Install mise-en-place
ENV PATH="/root/.local/share/mise/shims:${PATH}" \
    MISE_TRUSTED_CONFIG_PATHS="/workspace"
RUN set -eux; \
    curl -fsSL https://mise.run | MISE_VERSION="$MISE_VERSION" sh; \
    mise --version && \
    echo 'eval "$(mise activate bash)"' >> ~/.bashrc

# Install project tooling
COPY mise.toml ./mise.toml
RUN set -eux; \
    mise install; \
    # TODO: Add checks for mise tools
    rm mise.toml

# Install Claude Code
RUN set -eux; \
  curl -fsSL https://claude.ai/install.sh | bash; \
  claude --version

CMD ["bash"]
