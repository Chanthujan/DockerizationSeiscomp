FROM seiscomp:6.7.6

ENV TZ=Pacific/Auckland
ENV DEBIAN_FRONTEND=noninteractive

# Become root for package installs and file perms
USER root

# Install supervisord (if the base image doesn't already have it)
RUN apt-get update && \
    apt-get install -y --no-install-recommends supervisor ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Copy files with correct owners/permissions
COPY supervisord.conf /etc/supervisord.conf
COPY --chown=sysop:sysop etc/global.cfg /home/sysop/seiscomp/etc/global.cfg
COPY --chmod=0755 entrypoint.sh /entrypoint.sh
COPY --chown=sysop:sysop inventory/inventoryGeoNet.xml /home/sysop/seiscomp/etc/inventory/inventoryGeoNet.xml
COPY --chown=sysop:sysop key /home/sysop/seiscomp/etc/key
COPY --chown=sysop:sysop msrtsimul /home/sysop/seiscomp/bin/msrtsimul

# Tighten key perms and ensure binaries are executable
RUN chmod -R go-rwx /home/sysop/seiscomp/etc/key || true && \
    chmod +x /home/sysop/seiscomp/bin/msrtsimul

WORKDIR /home/sysop/seiscomp

# Start via entrypoint (does seiscomp update-config as sysop, then runs supervisord)
ENTRYPOINT ["/entrypoint.sh"]
