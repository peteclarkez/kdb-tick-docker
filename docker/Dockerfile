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

WORKDIR /root

# Download and run the KDB-X installer in non-interactive mode
# Uses BuildKit secrets so credentials are never stored in image layers
# Remove license file to prevent it from being included in the final image
RUN --mount=type=secret,id=kx_bearer_token \
    --mount=type=secret,id=kx_license_b64 \
    KX_BEARER_TOKEN="$(cat /run/secrets/kx_bearer_token)" && \
    KX_LICENSE_B64="$(cat /run/secrets/kx_license_b64)" && \
    if [ -z "$KX_BEARER_TOKEN" ]; then echo "ERROR: kx_bearer_token secret is required" && exit 1; fi && \
    if [ -z "$KX_LICENSE_B64" ]; then echo "ERROR: kx_license_b64 secret is required" && exit 1; fi && \
    curl -sLO --oauth2-bearer "$KX_BEARER_TOKEN" \
      https://portal.dl.kx.com/assets/raw/kdb-x/install_kdb/~latest~/install_kdb.sh && \
    bash install_kdb.sh -y --b64lic "$KX_LICENSE_B64" && \
    rm -f install_kdb.sh && \
    rm -f /root/.kx/kc.lic

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

# Default mount point paths (can be overridden at runtime)
ENV TICK_DATA_DIR=/data
ENV TICK_LOG_DIR=/logs
ENV TICK_TPLOG_DIR=/tplogs
ENV TICK_SCRIPTS_DIR=/scripts

# Create kdb user and group
RUN groupadd -r kdb && useradd -r -g kdb -m -s /bin/bash kdb

# Copy KDB-X installation from builder stage
COPY --from=builder --chown=kdb:kdb /root/.kx /home/kdb/.kx

# Create tick home and mount point directories
RUN mkdir -p ${Q_TICKHOME}/tick \
    /data \
    /logs \
    /tplogs \
    /scripts && \
    chown -R kdb:kdb ${Q_TICKHOME} /data /logs /tplogs /scripts && \
    chmod -R 775 ${Q_TICKHOME} /data /logs /tplogs /scripts

# Copy license setup script to /etc/profile.d for interactive shells
# and to tick home for sourcing in tick.sh
COPY docker/kx-license.sh /etc/profile.d/kx-license.sh
COPY --chown=kdb:kdb docker/kx-license.sh ${Q_TICKHOME}/kx-license.sh
RUN chmod +x /etc/profile.d/kx-license.sh ${Q_TICKHOME}/kx-license.sh

# Switch to kdb user for venv setup
USER kdb
WORKDIR /home/kdb

# Create virtual environment and install pykx
RUN python3.13 -m venv ${VIRTUAL_ENV} && \
    ${VIRTUAL_ENV}/bin/pip install --upgrade pip && \
    ${VIRTUAL_ENV}/bin/pip install --upgrade --pre pykx && \
    python -c "import pykx as kx; kx.install_into_QHOME()"

# Copy tick startup script
COPY --chown=kdb:kdb docker/tick.sh ${Q_TICKHOME}/

# Copy core tick scripts (excluding sym.q and feed.q which come from /scripts)
COPY --chown=kdb:kdb kdb-tick/tick.q ${Q_TICKHOME}/
COPY --chown=kdb:kdb kdb-tick/tick/u.q ${Q_TICKHOME}/tick/
COPY --chown=kdb:kdb kdb-tick/tick/r.q ${Q_TICKHOME}/tick/
COPY --chown=kdb:kdb kdb-tick/tick/hdb.q ${Q_TICKHOME}/tick/
COPY --chown=kdb:kdb kdb-tick/tick/gw.q ${Q_TICKHOME}/tick/

# Make tick.sh executable
RUN chmod +x ${Q_TICKHOME}/tick.sh

# Volume mounts:
# /data    - HDB data (date partitions, sym file)
# /logs    - Application logs (tick.log, rdb.log, etc.)
# /tplogs  - Tickerplant binary event logs
# /scripts - User customization (sym.q required, feed.q and *_custom.q optional)
VOLUME ["/data", "/logs", "/tplogs", "/scripts"]

# Expose all kdb+ ports: Tickerplant, RDB, HDB, Gateway
EXPOSE 5010 5011 5012 5013

# Healthcheck - verify tickerplant port is open
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD lsof -i :5010 | grep -q LISTEN || exit 1

# Set working directory
WORKDIR ${Q_TICKHOME}

# Default command
CMD ["./tick.sh"]
