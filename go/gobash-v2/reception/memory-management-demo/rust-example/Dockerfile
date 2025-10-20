FROM rust:1.82

WORKDIR /app

COPY Cargo.toml .
COPY src/ ./src/

RUN cargo build --release
