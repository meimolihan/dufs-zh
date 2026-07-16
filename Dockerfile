# syntax=docker/dockerfile:1
# Build cache: cargo registry + target dir persist across builds
# Usage: docker buildx build --platform linux/amd64,linux/arm64 -t dufs .

FROM messense/rust-musl-cross:x86_64-musl AS amd64
FROM messense/rust-musl-cross:aarch64-musl AS arm64

FROM ${TARGETARCH} AS builder

# Step 1: copy only manifest + lockfile → cache dependency build
WORKDIR /src
COPY Cargo.toml Cargo.lock ./

# Create a dummy src/main.rs so `cargo install` can resolve workspace
RUN mkdir src && echo 'fn main() {}' > src/main.rs

# Build dependencies only (cached unless Cargo.toml/lock change)
RUN --mount=type=cache,target=/root/.cargo/registry \
    --mount=type=cache,target=/root/.cargo/git \
    --mount=type=cache,target=/src/target \
    cargo install --path . --root /
RUN rm -rf src

# Step 2: copy real source, rebuild only dufs itself
COPY . .

# Touch main.rs to force rebuild of the actual binary
RUN touch src/main.rs
RUN --mount=type=cache,target=/root/.cargo/registry \
    --mount=type=cache,target=/root/.cargo/git \
    --mount=type=cache,target=/src/target \
    cargo install --path . --root /

# Final stage: minimal image
FROM scratch
COPY --from=builder /bin/dufs /bin/dufs
STOPSIGNAL SIGINT
ENTRYPOINT ["/bin/dufs"]
