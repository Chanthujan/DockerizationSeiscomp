# Use the official/prebuilt SeisComP image
FROM seiscomp:6.7.6

ENV TZ=Pacific/Auckland
ENV DEBIAN_FRONTEND=noninteractive

# Become root for package installs & system config
USER root

# Install OpenSSH server + supervisord
RUN apt-get update && \
    apt-get install -y --no-install-recommends openssh-server supervisor ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# SSHD runtime dir (newer Ubuntu uses /run/sshd; /var/run/sshd is a symlink)
RUN mkdir -p /run/sshd && chmod 755 /run/sshd

# Hardened-ish SSH config:
# - enable password auth (so your chpasswd works)
# - allow sysop login, keep root login disabled (safer)
RUN sed -ri 's/^#?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -ri 's/^#?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config

# Set a password for sysop (change these in production or use keys)
RUN echo "sysop:sysoppass" | chpasswd || true
# (If you *really* want root login, swap the PermitRootLogin above and uncomment:)
# RUN echo "root:rootpass" | chpasswd || true

# Copy supervisord config
COPY supervisord.conf /etc/supervisord.conf

# Copy SeisComP configs & maps; ensure ownership
COPY global.cfg /home/sysop/seiscomp/etc/global.cfg
COPY maps /home/sysop/seiscomp/share/maps
RUN chown -R sysop:sysop /home/sysop/seiscomp/etc/global.cfg /home/sysop/seiscomp/share/maps || true

# Expose SSH and (optionally) SeisComP messaging port if you need it
EXPOSE 22
# EXPOSE 18180

# Start supervisord (will start sshd + scmaster)
ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
