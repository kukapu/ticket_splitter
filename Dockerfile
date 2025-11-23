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

# Copy assets if they exist
COPY priv priv
COPY assets assets
# Try to build assets if package.json exists
RUN if [ -f "assets/package.json" ]; then \
      npm --prefix ./assets ci && \
      mix assets.deploy; \
    fi

# Compile and build the application
COPY lib lib
RUN mix compile

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