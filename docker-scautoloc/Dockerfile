FROM seiscomp:6.7.6

COPY supervisord.conf /etc/supervisord.conf
COPY etc/global.cfg /home/sysop/seiscomp/etc/global.cfg
COPY Files/"your station configuration.xml" /home/sysop/seiscomp/etc/config.xml
COPY Files/"your station inventory xml" /home/sysop/seiscomp/etc/inventory/Inventory.xml
COPY Files/scautoloc.cfg /home/sysop/seiscomp/etc/scautoloc.cfg


ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]

