# 7. Media Streaming Stack (NZBDav, Rclone, Plex, Arrs) Kubernetes Migration Architecture

Date: 2026-09-16

## Status

Proposed (Evaluated; pending user deployment authorization)

---

## Context

The homelab environment currently runs a media streaming pipeline historically deployed via Docker Compose on the `dito` physical node at `/home/paulo/nzbdav-sandbox/`. 

The stack comprises:
1. **NZBDav**: WebDAV streaming server and SABnzbd-compatible virtual downloader exposing Usenet content directly without intermediate disk storage.
2. **Rclone**: Mounts the NZBDav WebDAV stream locally to `/mnt/nzbdav` via FUSE (`--vfs-cache-mode full`, `--links`).
3. **Plex Media Server**: Ingests the media library from `/library` (which holds symbolic links resolving to `/mnt/nzbdav/.ids/...`) and streams content to clients across the LAN and remote internet.
4. **Radarr & Sonarr**: Media automation managers that discover releases, send virtual NZB requests to NZBDav, and create the symlinked movie/episode file structures in `/library`.

With the cluster infrastructure migrated from physical laptops to the Proxmox VM (`mainframe` at `192.168.1.7`), we evaluated whether and how to transition this Docker Compose stack into declarative GitOps under Kubernetes (ArgoCD), backed by the dedicated Crucial 1TB SSD (`/var/openebs/local`).

---

## Technical Audit & Key Architectural Findings

Our read-only audit of the live data on `dito` and upstream Kubernetes patterns uncovered several non-negotiable constraints:

### 1. Absolute Symlink Parity (`/mnt/nzbdav`)
* **Finding:** The media library (`/library/movies` and `/library/tv`) contains 2,000+ files structured as absolute symbolic links:
  ```
  /library/movies/500 Days of Summer (2009)/500.Days.of.Summer.mkv
      -> /mnt/nzbdav/.ids/e/b/d/8/a/ebd8a24a-65b5-4dfd-8040-76919d4dab72
  ```
* **Constraint:** The target path `/mnt/nzbdav` is hardcoded into the filesystem symlinks. If the Rclone volume is mounted at any other path (e.g., `/media` or `/data`), all symlinks will break simultaneously, causing Plex to mark the entire library as `Unavailable`.
* **Requirement:** All consuming containers must mount the virtual filesystem at the exact root path `/mnt/nzbdav`.

### 2. The FUSE "Zombie Mount" Deadlock (`ENOTCONN`)
* **Finding:** Rclone operates as a user-space filesystem via `/dev/fuse`. In Kubernetes, sharing a FUSE mount across independent Pods requires `mountPropagation: Bidirectional` on the mount pod and `HostToContainer` on consumer pods.
* **Failure Mode:** If Rclone runs as a standalone deployment and terminates (OOM, rolling upgrade, network interruption), the kernel severs the FUSE file descriptor. The mount point `/mnt/nzbdav` becomes a zombie mount (`Transport endpoint is not connected` / `ENOTCONN`).
* **Consequence:** Consumer pods (`plex`, `radarr`, `sonarr`) freeze or crashloop. Kubelet cannot restart them cleanly while the underlying host directory is locked. Manual host intervention (`fusermount -uz /mnt/nzbdav`) is required to clear the lock.

### 3. Startup & Runtime Dependency Graphs
* **Finding:** In Docker Compose, `plex`, `radarr`, and `sonarr` declare:
  ```yaml
  depends_on:
    rclone-nzbdav:
      condition: service_healthy
  ```
  where `rclone-nzbdav` verifies `test -d /mnt/nzbdav/.ids`.
* **Constraint:** Kubernetes does not provide inter-Deployment `depends_on` primitives. If Plex boots before the Rclone mount is established, its library scanner may detect missing media files and purge cached metadata and watch progress from SQLite.

### 4. Plex Local Direct Play vs. Remote Relay Throttling
* **Finding:** Kubernetes pods execute within an isolated CNI overlay (`10.42.0.0/16`). Plex's native LAN discovery protocols (GDM/UPnP via UDP `32410-32414` and `1900`) cannot broadcast across the CNI boundary to local LAN devices (`192.168.1.0/24`).
* **Failure Mode:** Plex clients on the local network misidentify the server as remote and route through external Plex Relay servers, capping video bandwidth at **1–2 Mbps (720p transcode)**.
* **Requirement:** Plex must be exposed via the Cilium Gateway API (`plex.paulojauregui.com:443`) and explicitly configured with:
  * `LAN Networks`: `192.168.1.0/24,10.42.0.0/16`
  * `Custom server access URLs`: `https://plex.paulojauregui.com:443`

### 5. SQLite Concurrency & POSIX Locking
* **Finding:** Plex, Radarr, and Sonarr maintain state in SQLite databases running in WAL mode (`Plex Media Server.db`, `radarr.db`, `sonarr.db`).
* **Constraint:** SQLite over networked storage (NFS, SMB, SeaweedFS) causes database corruption or lock exhaustion (`database is locked`).
* **Requirement:** All `/config` volumes must be allocated directly from local block storage (`openebs-hostpath` on the dedicated Crucial 1TB SSD).

### 6. Container Privilege Dropping (`s6-overlay`)
* **Finding:** LinuxServer container images utilize `s6-overlay` with environment variables `PUID=1000` and `PGID=1000`.
* **Constraint:** Enforcing `runAsUser: 1000` in the Kubernetes `securityContext` causes the container to crash on boot because `s6-overlay` requires root at startup to configure internal permissions before dropping privileges.

### 7. Transcoding Hardware Availability
* **Finding:** `mainframe` (Proxmox VM 102) currently operates on virtual QEMU standard VGA (`00:01.0`) without physical GPU passthrough (`/dev/dri/renderD128` is absent).
* **Constraint:** Plex will rely on software CPU transcoding. While 16 vCPUs handle Direct Play and 1080p transcodes with ease, heavy 4K HDR tone-mapping will stress the host. Hardware passthrough should be evaluated in Proxmox prior to heavy remote streaming.

---

## Evaluated Architectural Patterns

### Pattern A: Unified Multi-Container Pod ("Pod-as-a-Stack") — SELECTED
Run `nzbdav`, `rclone`, `plex`, `radarr`, and `sonarr` inside a single `StatefulSet` pod:

* **Ordering:** Enforced natively via KEP-753 Sidecar Containers (`initContainers` with `restartPolicy: Always` for NZBDav and Rclone) followed by an Init Barrier container (`until [ -d /mnt/nzbdav/.ids ]; do sleep 2; done`) before main apps start.
* **FUSE Safety:** The virtual mount is shared inside the pod namespace via an `emptyDir` or pod-local volume. If Rclone crashes, the entire pod restarts atomically, eliminating the possibility of zombie mounts.
* **Networking:** Radarr and Sonarr talk to NZBDav via `127.0.0.1:3000` on the loopback interface, eliminating network hops.
* **Trade-off:** Updating an individual component (e.g., Radarr) triggers a restart of the entire 5-container pod (~10 seconds).

### Pattern B: Independent Deployments via HostPath Mount
Run `nzbdav`, `rclone`, `plex`, `radarr`, and `sonarr` as 4 separate Deployments:

* **Ordering:** Each consumer deployment includes an `initContainer` waiting for `/mnt/nzbdav/.ids` on the host.
* **Trade-off:** High operational fragility. If `rclone` restarts mid-flight, all consumer pods lock up in `ENOTCONN` until manual intervention occurs.

### Pattern C: Host Systemd Rclone Mount
Run `rclone` as a native `systemd` service directly on the Ubuntu host OS (`mainframe`), mounting `/mnt/nzbdav` on the host filesystem:

* **Ordering:** Very stable; managed by standard Linux service monitoring.
* **Trade-off:** Breaks 100% declarative GitOps by maintaining infrastructure outside Kubernetes.

---

## Decision

When the migration is executed, **Pattern A (Unified Multi-Container Pod)** is selected as the target architecture. 

It provides:
1. Complete fidelity to Docker Compose's `depends_on: condition: service_healthy` semantics.
2. Complete immunity to FUSE `ENOTCONN` zombie mounts.
3. Sub-millisecond communication between automation managers and the Usenet streaming engine.
4. Total encapsulation in GitOps manifests (`apps/base/media`).

### Immediate Operational Plan
The Docker Compose media stack will remain running undisturbed on `dito` for current media consumption. When authorized, the migration will proceed according to this specification:
1. `rsync -avzP /home/paulo/nzbdav-sandbox/config/ /var/openebs/local/media-config/` on `mainframe`.
2. `rsync -avzP /home/paulo/nzbdav-sandbox/library/ /var/openebs/local/media-library/` on `mainframe`.
3. Commit and push the Pattern A `StatefulSet` manifests and Gateway API `HTTPRoute`s to `k8s-gitops`.
4. Decommission the Docker Compose stack on `dito`.
