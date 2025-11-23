# Use the official Elixir image with a specific version
FROM hexpm/elixir:1.18.0-erlang-27.3.4.1-debian-bookworm-20251117 AS builder

# Install build dependencies
RUN apk add --no-cache build-essential npm git python3

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
FROM alpine:3.18 AS app

RUN apk add --no-cache openssl ncurses-libs

WORKDIR /app

RUN chown nobody:nobody /app

USER nobody:nobody

COPY --from=builder --chown=nobody:nobody /app/_build/${MIX_ENV}/rel/ticket_splitter ./

ENV HOME=/app

CMD ["bin/ticket_splitter", "start"]