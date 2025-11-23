# Use the official Elixir image with a specific version
FROM hexpm/elixir:1.18.3-erlang-27.3.3-debian-bookworm-20250407-slim AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    npm \
    git \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Prepare build directory
WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set arguments for build
ARG MIX_ENV=prod

# Install dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# Copy application code
COPY lib lib
COPY priv priv

# Compile the application first
RUN mix compile

# Copy assets and build them
COPY assets assets
RUN mix assets.setup
RUN mix assets.deploy

# Build release
COPY config/runtime.exs config/
RUN mix release

# Prepare a new image for the release
FROM debian:bookworm-slim AS app

RUN apt-get update && apt-get install -y \
    openssl \
    libncurses6 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN chown nobody:nogroup /app

ARG MIX_ENV=prod
COPY --from=builder --chown=nobody:nogroup /app/_build/${MIX_ENV}/rel/ticket_splitter ./

# Copy entrypoint script
COPY --chown=nobody:nogroup entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

USER nobody:nogroup

ENV HOME=/app

CMD ["/app/entrypoint.sh"]