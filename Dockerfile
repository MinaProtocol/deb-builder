FROM debian:stable-slim

# Install required dependencies (if any)
RUN apt-get update && apt-get install -y \
    ca-certificates git \
    && rm -rf /var/lib/apt/lists/*

# Copy the deb_builder executable
COPY _build/default/src/bin/deb_builder.exe /usr/local/bin/mina-debian-builder

# Make sure the binary is executable
RUN chmod +x /usr/local/bin/mina-debian-builder

# Set default command
ENTRYPOINT ["/usr/local/bin/mina-debian-builder"]