# 🐳 Dockerisation of SeisComP Modules

This repository provides a modular, containerised deployment for the SeisComP earthquake processing system using Docker. Each SeisComP module is isolated in its own container for flexible scaling, maintainability, and reproducibility.

#### Note: This setup is based on Ubuntu 24.04. You may need to update Dockerfiles if you are using a different Ubuntu version.

#### Prerequisites

```bash
Docker Engine >= 20.x
Git
Optional: X11 forwarding for scolv via SSH
```
## 🛠️ Step-by-Step Setup

### 1. Clone SeisComP Repository

Use the provided script to clone SeisComP into your desired directory:

```bash
chmod +x clone.sh
./clone.sh <target-directory>
```

### 2. Create SeisComP Tarball

Once the SeisComP source is downloaded, compress it into a seiscomp.tar.gz archive in the main Dockerfile directory (for use in the base image).
```bash
tar -czvf seiscomp.tar.gz <target-directory>
```
### 3. Place Your Station Inventory

Place your station inventory XML (e.g., GeoNet) inside the inventory/ folder.

### 4. Build the Base Image
```bash
chmod +x build.sh
./build.sh
```

This builds the base SeisComP image:
seiscomp:6.7.6

### 5. Create Docker Network
```bash
docker network create seiscomp-net
```

### 6. Set Up PostgreSQL Database
```bash
docker run -d \
  --name seiscomp-db \
  --network seiscomp-net \
  -e POSTGRES_USER=sysop \
  -e POSTGRES_PASSWORD=Ailove123 \
  -e POSTGRES_DB=seiscomp \
  -v pgdata:/var/lib/postgresql/data \
  postgres:15
```

This container acts as the database backend for SeisComP and the message bus (via scmp).
### 7. Build & Run Module Containers

Each SeisComP module is maintained in its own dedicated folder following the pattern docker-<module>/ (e.g., docker-scautopick/, docker-scmaster/, etc.).

Before building these Docker containers, make sure to prepare the following files for your network setup:

Inventory.xml: This contains your station metadata.

Config.xml: This includes station-specific configurations.

Once these files are prepared, add both Inventory.xml and Config.xml to the Files/ directory inside each relevant module folder (e.g., docker-scautopick/Files/).

After adding the files:

Update the Dockerfile in each module folder to copy these files into the appropriate location within the container (e.g., /home/sysop/seiscomp/inventory/ or /home/sysop/seiscomp/etc/).

Build the Docker image for the module to include the changes.

This setup ensures that each module has the correct station and configuration data embedded during the container build process.

Below is the command sequence: 

#### scevent
```bash
cd docker-scevent/
docker build -t seiscomp-scevent:latest .
docker run -d --name scevent --network seiscomp-net seiscomp-scevent:latest
docker logs scevent
```

#### scamp
```bash
cd docker-scamp/
docker build -t seiscomp-scamp:latest .
docker run -d --name scamp --network seiscomp-net seiscomp-scamp:latest
docker logs scamp
```


#### scautoloc
```bash
cd docker-scautoloc/
docker build -t seiscomp-scautoloc:latest .
docker run -d --name scautoloc --network seiscomp-net seiscomp-scautoloc:latest
```

#### scmag
```bash
cd docker-scmag/
docker build -t seiscomp-scmag:latest .
docker run -d --name scmag --network seiscomp-net seiscomp-scmag:latest
```

#### scautopick
```bash
cd docker-scautopick/
docker build -t seiscomp-scautopick:latest .
docker run -d --name scautopick --network seiscomp-net seiscomp-scautopick:latest
```

#### scmaster (with SSH access)
To build this module, you do not need to pass the inventory or configuration files.
```bash
cd docker-scmaster/
docker build -t seiscomp-scmaster:latest .
docker run -d -p 222:22 --name scmaster --network seiscomp-net seiscomp-scmaster:latest
```

#### seedlink
Before building the seedlink container, add the bindings to the folder named key in the docker-seedlink directory
```bash
cd docker-seedlink/
docker build -t seiscomp-seedlink:latest .
docker run -d --name seedlink --network seiscomp-net seiscomp-seedlink:latest
```

### 8. Load SeisComP Schema into PostgreSQL
#### 1. Enter scmaster container
```bash
docker exec -u root -it scmaster bash
```

#### 2. Switch to sysop
```bash
su sysop
```

#### 3. Install PostgreSQL client (if needed)
```bash
apt update && apt install -y postgresql-client
```

#### 4. Load the schema
```bash
psql -h seiscomp-db -U sysop -d seiscomp -f /home/sysop/seiscomp/share/db/postgres.sql
```

#### 5. Verify schema
```bash
psql -h seiscomp-db -U sysop -d seiscomp -c '\dt'
```

#### 6. Update Configuration inside the scmaster module
```bash
seiscomp update-config
```

This loads the inventory and configuration into the database.


### 9. Feed Earthquake Data with msrtsimul
1. Upload your MiniSEED file to the seedlink container
```bash
docker cp myfile.mseed seedlink:/home/sysop/seiscomp/groundMotionData/
```
2. Run simulation
```bash
docker exec -u sysop -it seedlink bash
seiscomp exec msrtsimul -v -m historic groundMotionData/myfile.mseed
```

### 10. Visualise Events with scolv
1. Set password for sysop (first time only)
```bash
docker exec -u root -it scmaster bash
passwd sysop
```
2. Run scolv via SSH with X11 forwarding
```bash
ssh -X -p 222 sysop@localhost \
XDG_RUNTIME_DIR=/tmp/runtime-sysop \
/home/sysop/seiscomp/bin/seiscomp exec scolv \
-d postgresql://sysop:Ailove123@seiscomp-db/seiscomp --offline
```

You should now see the SeisComP event visualisation interface.

✅ Final Notes

Once all modules are running, and SeedLink is feeding data, your Dockerised SeisComP system will operate just like a traditional monolithic setup—only now with full containerisation support, version control, and easier cloud deployments.
