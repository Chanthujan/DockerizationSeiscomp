# ==============================================================================
# SeisComP Multi-stage Dockerfile (Ubuntu 24.04 / Noble)
# - Robust tar extraction (no self-move issues)
# - Explicit CMake -S/-B usage
# - Safe, overrideable sysop user/group creation (auto-fallback if IDs taken)
# - Optional GUI support via ARG GUI=ON|OFF (default OFF)
# - Python deps installed in a user venv to avoid PEP 668 issues
# ==============================================================================

# Shared build args (available to all stages)
ARG SEISCOMP_ROOT="/home/sysop/seiscomp"
ARG GUI=OFF

# ------------------------------------------------------------------------------
# Build Stage: compile SeisComP from the provided tarball
# ------------------------------------------------------------------------------
FROM ubuntu:24.04 AS build-stage

ARG SEISCOMP_ROOT
ARG GUI

ENV DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC

# Base + toolchain and build dependencies
RUN apt-get update && apt-get install -y \
    tzdata \
    software-properties-common && \
    add-apt-repository universe && \
    apt-get update && apt-get -y dist-upgrade && \
    apt-get install -y \
    git \
    build-essential \
    cmake \
    flex \
    libcrypto++-dev \
    libfl-dev \
    libpq-dev \
    libssl-dev \
    openssl \
    libxml2-dev \
    python3 \
    python3-dev \
    python3-pip \
    python3-numpy \
    libboost-all-dev \
    libbson-dev \
    libmongoc-dev && \
    if [ "${GUI}" = "ON" ]; then \
      apt-get install -y qtbase5-dev libqt5svg5 libqt5svg5-dev libqt5gui5; \
    fi && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Provide the SeisComP sources as a gzipped tarball in the build context
# e.g. put 'seiscomp.tar.gz' alongside this Dockerfile.
COPY seiscomp.tar.gz /tmp/seiscompsrc.tar.gz

# Robust extraction: unpack into a temp dir, then rename to /tmp/seiscomp
RUN set -eux; \
    mkdir -p /tmp/src; \
    tar -xzf /tmp/seiscompsrc.tar.gz -C /tmp/src; \
    rm -f /tmp/seiscompsrc.tar.gz; \
    top="$(ls -1 /tmp/src | head -1)"; \
    mv "/tmp/src/${top}" /tmp/seiscomp

# Configure + build + install to SEISCOMP_ROOT (staged in this image layer)
RUN cmake -S /tmp/seiscomp -B /tmp/seiscomp/build \
      -DCMAKE_INSTALL_PREFIX="${SEISCOMP_ROOT}" \
      -DSC_GLOBAL_UNITTESTS=OFF \
      -DSC_GLOBAL_GUI="${GUI}" \
      -DSC_TRUNK_DB_POSTGRESQL=ON \
      -DSC_TRUNK_DB_MYSQL=OFF \
      -DSC_GLOBAL_PYTHON_WRAPPER_PYTHON3=ON && \
    cmake --build /tmp/seiscomp/build -j"$(nproc)" --target install

# ------------------------------------------------------------------------------
# Runtime Stage: minimal runtime dependencies + copy compiled SeisComP
# ------------------------------------------------------------------------------
FROM ubuntu:24.04 AS final-stage

ARG SEISCOMP_ROOT
ARG GUI

LABEL maintainer="R&D Seismology and Acoustics" \
      description="SeisComP runtime Docker image" \
      license="AGPL"

ENV DEBIAN_FRONTEND=noninteractive TZ=Pacific/Auckland

# Base runtime + updates
RUN apt-get update && apt-get install -y \
    tzdata \
    software-properties-common && \
    add-apt-repository universe && \
    apt-get update && apt-get -y dist-upgrade

# Runtime dependencies
# Note: For simplicity we keep libboost-all-dev; switch to specific runtime libs if you need a slimmer image.
RUN apt-get install -y \
    libboost-all-dev \
    libpq5 \
    python3 \
    python3-dev \
    python3-pip \
    python3-numpy \
    python3-venv \
    git \
    gettext \
    vim \
    supervisor \
    libbson-1.0-0 \
    libmongoc-1.0-0 && \
    if [ "${GUI}" = "ON" ]; then \
      apt-get install -y libqt5gui5 libqt5svg5; \
    fi && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ---------------------- Safe sysop user creation ------------------------------
# Override at build time to match your host IDs for bind mounts:
#   --build-arg SYSOP_UID=$(id -u) --build-arg SYSOP_GID=$(id -g)
# Defaults to 1010 to avoid collisions with common 1000:1000 users.
ARG SYSOP_UID=1010
ARG SYSOP_GID=1010

RUN set -eux; \
    # Find a free GID if requested GID already exists
    free_gid="${SYSOP_GID}"; \
    while getent group "${free_gid}" >/dev/null; do \
      free_gid=$((free_gid+1)); \
    done; \
    groupadd -r -g "${free_gid}" sysop || true; \
    grp_name="$(getent group "${free_gid}" | cut -d: -f1 || echo sysop)"; \
    # Find a free UID if requested UID already exists
    free_uid="${SYSOP_UID}"; \
    while getent passwd "${free_uid}" >/dev/null; do \
      free_uid=$((free_uid+1)); \
    done; \
    # Create user if missing; otherwise adjust it
    if id -u sysop >/dev/null 2>&1; then \
      usermod -s /bin/bash -g "${grp_name}" -u "${free_uid}" sysop || true; \
    else \
      useradd -m -s /bin/bash -r -g "${grp_name}" -u "${free_uid}" sysop; \
    fi

# ---------------------- Copy compiled SeisComP from build stage ---------------
COPY --from=build-stage ${SEISCOMP_ROOT} ${SEISCOMP_ROOT}

# ---------------------- App working directory ---------------------------------
WORKDIR ${SEISCOMP_ROOT}

# ---------------------- Python requirements (provided in build context) -------
COPY requirements.txt ${SEISCOMP_ROOT}/requirements.txt

# ---------------------- Inventory (provided in build context) -----------------
COPY inventory /tmp/inventory

# ---------------------- SeisComP setup: dirs, env, inventory merge ------------
RUN set -eux; \
    rm -rf ./var && \
    mkdir -p /home/sysop/.seiscomp/log \
             ./var/log \
             ./var/run \
             ./var/lib \
             ./etc/inventory && \
    ./bin/seiscomp --asroot exec scxmlmerge --plugins dbpostgresql /tmp/inventory/*.xml \
      > ./etc/inventory/inventory.xml && \
    rm -rf /tmp/inventory && \
    ./bin/seiscomp --asroot print env >> /home/sysop/.bash_profile && \
    ./bin/seiscomp --asroot print env >> /home/sysop/.bashrc && \
    chown -R sysop:sysop /home/sysop

# ---------------------- Install Python libs in a user venv (fixes PEP 668) ----
USER sysop
ENV VIRTUAL_ENV=/home/sysop/.venv
ENV PATH="${VIRTUAL_ENV}/bin:${PATH}"

RUN python3 -m venv "${VIRTUAL_ENV}" && \
    "${VIRTUAL_ENV}/bin/pip" install --upgrade pip==24.2 && \
    "${VIRTUAL_ENV}/bin/pip" install --no-warn-script-location -r "${SEISCOMP_ROOT}/requirements.txt" && \
    rm -f "${SEISCOMP_ROOT}/requirements.txt"

# Default entry point: interactive bash (override with `docker run ... <cmd>`)
ENTRYPOINT ["/bin/bash", "-c"]
