FROM seiscomp:6.7.6

COPY supervisord.conf /etc/supervisord.conf
COPY etc/global.cfg /home/sysop/seiscomp/etc/global.cfg


COPY Files/configNew.xml /home/sysop/seiscomp/etc/configNew.xml
COPY Files/geoNetInv.xml /home/sysop/seiscomp/etc/inventory/geoNetInv.xml

ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]

