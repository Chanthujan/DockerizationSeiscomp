FROM seiscomp:6.7.6

COPY supervisord.conf /etc/supervisord.conf
COPY etc/global.cfg /home/sysop/seiscomp/etc/global.cfg

COPY Files/Config.xml /home/sysop/seiscomp/etc/Config.xml
COPY Files/Inventory.xml /home/sysop/seiscomp/etc/inventory/Inventory.xml


ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]

