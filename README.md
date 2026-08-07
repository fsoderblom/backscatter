# Backscatter

Detect anomalies on a corporate network by analyzing traffic routed to a dedicated sink host.

## Prerequisites

- Linux server running RHEL7, RHEL8, or RHEL9
- Two ethernet interfaces:
  - **ens192** — management interface, used for administrative access
  - **ens666** — monitor interface, receives all traffic to be analyzed
- The corporate network's default route (or routes covering unallocated IP space) must point to this machine's **ens666** interface. Any traffic arriving on it has no legitimate destination and is treated as anomalous.
- The machine's own default route must go out via **ens666**, so return traffic follows the same path. Static routes on **ens192** (see step 4) ensure that administrative traffic uses the management interface and routes symmetrically.

## How it works

Traffic from the corporate network with no legitimate internal destination is routed to **ens666**. `feed-routes.sh` reads the monitored CIDR ranges from `/opt/backscatter/etc/cidr-ranges.conf`, installs local kernel routes for each, and adds iptables TPROXY rules to redirect inbound TCP to `anyip-listener`. The listener completes the TCP handshake and sends a short response before closing, prompting the client to transmit its first application payload — which is captured in the PCAP.

All traffic on ens666 is captured by `fifo` (tcpdump) in rotating PCAP files at `/var/opt/fifo/`. iptables logs new inbound connections to `/var/log/iptables.log`, which the `backscatter` daemon tails continuously. It whitelists known-good destinations (CDNs, Microsoft, Cloudflare, root DNS, open resolvers, etc.), records all events to the `matches` database table, and tracks the number of unique destination IPs each source has tried to reach. Alerts fire at dampening thresholds of 10, 25, 50, 75, 150, 300, 600 and 1200 unique destinations by dropping a semaphore in `/var/spool/backscatter/`.

`report_backscatter` polls that spool every two minutes. For each flagged source it optionally runs an nmap scan (internal ranges only, rate-limited to one scan per hour per host), fetches the last 100 database entries, generates an Afterglow graph, and writes a timestamped report and PNG to `/u/backscatter/<srcip>/`. `/u/backscatter` is intended to be a SAN or shared volume that the SOC team can mount directly to browse reports and graphs. A `local6.error` syslog alert is emitted to `alerts.log`; the SOC can consume this by polling the file or by forwarding it to a SIEM — uncomment the `@@siem` lines in `etc/rsyslog.d/backscatter.conf` to enable syslog forwarding. If the share is unavailable the report falls back to `/u/offline/` and email.

The web interface provides search and filtering of the `matches` database, Afterglow traffic maps, live tail, CSV/raw/HTML export, and a PCAP browser for downloading capture files.

## Installation

Throughout these steps `<git>` refers to the root of your local clone of this repository.

### 1. Create a dedicated user

```bash
useradd -c "Backscatter user" scatter
```

### 2. Deploy web interface files

```bash
mkdir /srv
chmod 555 /srv
cp -a <git>/root/srv/ /srv/
```

### 3. Install backscatter, afterglow, and fifo

```bash
cp -a <git>/root/opt/ /opt/
```

Clone and install afterglow from https://github.com/fsoderblom/afterglow — the color.properties configuration files for backscatter are included in this repo under `root/opt/afterglow/etc/` and will be copied into place by the `cp -a` command above.

Before starting services, review and edit the following files:

- **`/opt/backscatter/sbin/report_backscatter`** — set `MAIL_TO` to the address that should receive alerts when the SAN share is unavailable.
- **`/opt/backscatter/sbin/backscatter`** — review the filtering section and replace the example `srcip/me` whitelist entry with your own exclusions.
- **`/opt/backscatter/etc/cidr-ranges.conf`** — pre-populated with all public IPv4 space; trim to match only the ranges actually routed to ens666.

### 4. Configure static routes for the management interface

**RHEL7/8:** Edit and copy the route file:
```bash
vi <git>/root/etc/sysconfig/network-scripts/route-ens192
cp <git>/root/etc/sysconfig/network-scripts/route-ens192 /etc/sysconfig/network-scripts/
```

**RHEL9:** `network-scripts` has been removed. Configure routes via NetworkManager instead (use `<git>/root/etc/sysconfig/network-scripts/route-ens192` as a reference for which routes to add):
```bash
nmcli con mod ens192 +ipv4.routes "<destination> <gateway>"
nmcli con up ens192
```

### 5. Apply sysctl settings

```bash
cp <git>/root/etc/sysctl.d/zz-backscatter.conf /etc/sysctl.d/
sysctl -p /etc/sysctl.d/zz-backscatter.conf
```

### 6. Install dependencies

```bash
dnf -y install tcpdump lsof nmap graphviz pcre2-tools perl-File-Tail perl-Net-CIDR perl-Text-CSV perl-Date-Manip nginx mariadb mariadb-server nginx-mod-mail nginx-mod-http-xslt-filter nginx-all-modules nginx-filesystem nginx-mod-http-image-filter nginx-mod-http-perl nginx-mod-stream php php-fpm php-mysqlnd php-common php-cli php-pdo openssl-devel iptables-services
```

### 7. Configure iptables

All chains default to ACCEPT. Disable firewalld to avoid conflicts with iptables-services, add a logging rule for new inbound connections on the monitor interface that are not destined for the machine itself, then save the ruleset and enable the service:

```bash
systemctl disable --now firewalld
iptables -A INPUT ! -d <ip-of-ens666>/32 -i ens666 -m state --state NEW -j LOG
iptables-save > /etc/sysconfig/iptables
systemctl enable --now iptables
```

### 8. Configure NGINX

```bash
cp <git>/root/etc/nginx/nginx.conf /etc/nginx/nginx.conf
```

Create the TLS directory and install your server certificate and key:

```bash
mkdir -p /etc/nginx/tls
cp server.crt /etc/nginx/tls/
cp server.key /etc/nginx/tls/
chmod 600 /etc/nginx/tls/server.key
```

Generate a DH parameter file (this takes a few minutes):

```bash
openssl dhparam -out /etc/nginx/tls/dhparam.pem 4096
```

The following are optional but recommended — edit `nginx.conf` to enable them:

- **mTLS** — install your client CA certificate as `/etc/nginx/tls/client-ca.pem`, then uncomment `ssl_verify_client on` and the `if ($ssl_client_verify != SUCCESS)` block in the `location /` stanza to restrict access to certificate-holding clients only.
- **OCSP stapling** — uncomment `ssl_stapling`, `ssl_stapling_verify`, and `resolver`, replacing `DNS1 DNS2` with your internal resolvers.
- **HSTS** — uncomment the `Strict-Transport-Security` header once TLS is confirmed working.

Once the configuration is in place, verify and enable NGINX:

```bash
nginx -t
systemctl enable --now nginx php-fpm
```

### 9. Create directories

```bash
mkdir -p /u/backscatter/ /u/offline/ /var/spool/backscatter/scan
chown -R scatter:scatter /u/backscatter/ /u/offline/ /var/spool/backscatter
```

### 10. Configure sudo

```bash
cp <git>/root/etc/sudoers.d/backscatter /etc/sudoers.d/backscatter
```

### 11. Configure rsyslog

```bash
cp <git>/root/etc/rsyslog.d/backscatter.conf /etc/rsyslog.d/
cp <git>/root/etc/rsyslog.d/audispd.conf /etc/rsyslog.d/
systemctl restart rsyslog.service
```

### 12. Configure logrotate

```bash
cp <git>/root/etc/logrotate.d/backscatter /etc/logrotate.d/
```

### 13. Enable and start MariaDB

```bash
systemctl enable --now mariadb
mysql_secure_installation
```

### 14. Set up the database

```bash
mysql -u root -e "CREATE DATABASE backscatter;"
mysql -u root backscatter < <git>/doc/create_tables.sql
```

### 15. Grant database access

```sql
CREATE USER 'backscatter'@'localhost' IDENTIFIED BY '<secret>';
GRANT ALL PRIVILEGES ON `backscatter`.* TO 'backscatter'@'localhost';
CREATE USER 'bracksmatter'@'localhost' IDENTIFIED BY '<secret>';
GRANT SELECT ON `backscatter`.* TO 'bracksmatter'@'localhost';
```

### 16. Configure database credentials for the backscatter daemon

Create `/home/scatter/.my.cnf` with the password set in step 14, readable only by the scatter user:

```bash
cat > /home/scatter/.my.cnf << 'EOF'
[backscatter]
user=backscatter
password=<secret>
host=localhost
EOF
chmod 600 /home/scatter/.my.cnf
chown scatter:scatter /home/scatter/.my.cnf
```

### 17. Configure database credentials for the web interface

Create `/etc/backscatter/db.ini` outside the web root with the password set in step 14, readable only by the PHP-FPM process:

```bash
mkdir -p /etc/backscatter
cat > /etc/backscatter/db.ini << 'EOF'
host=localhost
user=bracksmatter
password=<secret>
database=backscatter
EOF
chmod 640 /etc/backscatter/db.ini
chown root:nginx /etc/backscatter/db.ini
```

### 18. Enable and start services

```bash
cp <git>/root/etc/systemd/system/anyip-listener.service /etc/systemd/system/
cp <git>/root/etc/systemd/system/backscatter.service /etc/systemd/system/
cp <git>/root/etc/systemd/system/report_backscatter.service /etc/systemd/system/
cp <git>/root/etc/systemd/system/feed-routes.service /etc/systemd/system/
cp <git>/root/etc/systemd/system/fifo.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now anyip-listener.service backscatter.service report_backscatter.service feed-routes.service fifo.service
```
