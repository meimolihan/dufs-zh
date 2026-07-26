# syntax=docker/dockerfile:1
# Build: docker buildx build --platform linux/amd64,linux/arm64 -t dufs .
# Cache: cargo registry + target dir persist across builds via BuildKit cache mounts

FROM messense/rust-musl-cross:x86_64-musl AS amd64
FROM messense/rust-musl-cross:aarch64-musl AS arm64

FROM ${TARGETARCH} AS builder

WORKDIR /src

# ---- Stage 1: build dependencies only (cached unless Cargo.toml/lock change) ----
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo 'fn main() {}' > src/main.rs

RUN --mount=type=cache,target=/root/.cargo/registry \
    --mount=type=cache,target=/root/.cargo/git \
    --mount=type=cache,target=/src/target \
    cargo install --path . --root /

# ---- Stage 2: copy real source, rebuild only dufs itself ----
COPY . .

RUN --mount=type=cache,target=/root/.cargo/registry \
    --mount=type=cache,target=/root/.cargo/git \
    --mount=type=cache,target=/src/target \
    touch src/main.rs src/server.rs && \
    cargo install --path . --root /

# ---- Final stage: minimal image ----
FROM scratch
COPY --from=builder /bin/dufs /bin/dufs
STOPSIGNAL SIGINT
ENTRYPOINT ["/bin/dufs"]
