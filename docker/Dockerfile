# =============================================================================
# Stage 1: Base Image
# Ubuntu 24.04 with Python 3.13 from deadsnakes PPA
# =============================================================================
FROM ubuntu:24.04 AS base

ENV DEBIAN_FRONTEND=noninteractive

# Install required packages and deadsnakes PPA for Python 3.13
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    gnupg \
    ca-certificates \
    curl \
    && add-apt-repository -y ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y --no-install-recommends \
    python3.13 \
    python3.13-venv \
    python3.13-dev \
    rlwrap \
    lsof \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# Stage 2: Build Stage
# Download and install KDB-X
# =============================================================================
FROM base AS builder

# Build arguments for KX authentication
ARG KX_BEARER_TOKEN
ARG KX_LICENSE_B64

# Verify build arguments are provided
RUN if [ -z "$KX_BEARER_TOKEN" ]; then echo "KX_BEARER_TOKEN is required" && exit 1; fi && \
    if [ -z "$KX_LICENSE_B64" ]; then echo "KX_LICENSE_B64 is required" && exit 1; fi

WORKDIR /root

# Download and run the KDB-X installer in non-interactive mode
RUN curl -sLO --oauth2-bearer "$KX_BEARER_TOKEN" \
    https://portal.dl.kx.com/assets/raw/kdb-x/install_kdb/~latest~/install_kdb.sh && \
    bash install_kdb.sh -y --b64lic "$KX_LICENSE_B64" && \
    rm -f install_kdb.sh

# =============================================================================
# Stage 3: Runtime Stage
# Production image with kdb user and tick system
# =============================================================================
FROM base AS runtime

# Environment variables for KDB-X
# KDB-X installs to ~/.kx with bin/ containing the q executable
ENV QHOME=/home/kdb/.kx
ENV QLIC=/home/kdb/.kx
ENV PATH="/home/kdb/.kx/bin:${PATH}"
ENV Q_TICKHOME=/opt/kx/kdb-tick
ENV VIRTUAL_ENV=/home/kdb/venv
ENV PATH="${VIRTUAL_ENV}/bin:${PATH}"

# Create kdb user and group
RUN groupadd -r kdb && useradd -r -g kdb -m -s /bin/bash kdb

# Copy KDB-X installation from builder stage
COPY --from=builder --chown=kdb:kdb /root/.kx /home/kdb/.kx

# Create tick directories
RUN mkdir -p ${Q_TICKHOME}/tick \
    /data/tick \
    /scripts && \
    chown -R kdb:kdb ${Q_TICKHOME} /data /scripts && \
    chmod -R 775 ${Q_TICKHOME} /data /scripts

# Switch to kdb user for venv setup
USER kdb
WORKDIR /home/kdb

# Create virtual environment and install pykx
RUN python3.13 -m venv ${VIRTUAL_ENV} && \
    ${VIRTUAL_ENV}/bin/pip install --upgrade pip && \
    ${VIRTUAL_ENV}/bin/pip install --upgrade --pre pykx && \
    python -c "import pykx as kx; kx.install_into_QHOME()"

# Copy tick scripts
COPY --chown=kdb:kdb docker/tick.sh ${Q_TICKHOME}/
COPY --chown=kdb:kdb kdb-tick/*.q ${Q_TICKHOME}/
COPY --chown=kdb:kdb kdb-tick/tick/*.q ${Q_TICKHOME}/tick/

# Make tick.sh executable
RUN chmod +x ${Q_TICKHOME}/tick.sh

# Volume mounts for data and custom scripts
VOLUME ["/data/tick", "/scripts"]

# Expose all kdb+ ports: Tickerplant, RDB, HDB, Gateway
EXPOSE 5010 5011 5012 5013

# Healthcheck - verify tickerplant port is open
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD lsof -i :5010 | grep -q LISTEN || exit 1

# Set working directory
WORKDIR ${Q_TICKHOME}

# Default command
CMD ["./tick.sh"]
