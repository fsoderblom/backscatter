# Backscatter

Automatically detect anomalies on a corporate internal network

## Pre-requisite
A Linux server with RHEL7 (should prolly work fine with later releases too)
Two ethernet interfaces, one for management and one to receive the traffic to be monitored
Default route should go out thru the monitor interface

## Steps
1. Add a user for backscatter
```bash
useradd -c "Backscatter user" scatter
```
2. Download the latest version of nmap and compile it (optional)
```bash
tar zxvf nmap-X.XX.tgz
cd nmap-X.XX
./configure
make
make install
```

3. Copy files required for the web interface
```bash
mkdir /srv
chmod 555 /srv
cp -a <git>/root/srv/ /srv/
```
4.  Install afterglow, backscatter and fifo
```bash
cp -a <git>/root/opt/ /opt/
```
Fetch and install afterglow from https://afterglow.sourceforge.net/

5. Ensure all neccesary static routes are in place for the management interface
```bash
vi <git>/root/etc/sysconfig/network-scripts/route-ens192
cp <git>/root/etc/sysconfig/network-scripts/route-ens192 /etc/sysconfig/network-scripts/
```
6. Install sysctl configuration file for backscatter
```bash
cp <git>/root/etc/sysctl.d/zz-backscatter.conf /etc/sysctl.d/
sysctl -p /etc/sysctl.d/zz-backscatter.conf
```
7.  Install required RPM's
```bash
yum -y install tcpdump lsof rcs 
yum -y install pcre-tools perl-File-Tail perl-Net-CIDR perl-Text-CSV perl-Date-Manip 
yum -y install nginx mariadb mariadb-server nginx nginx-mod-mail nginx-mod-http-xslt-filter nginx-all-modules nginx-filesystem nginx-mod-http-image-filter nginx-mod-http-perl nginx-mod-stream php php-fpm php-mysql php-common php-cli php-pdo
yum -y install openssl-devel
```
8. Install the configuration file for NGINX
```bash
cp <git>/root/etc/nginx/nginx.conf /etc/nginx.conf
```
9. Create neccesary directories
```bash
mkdir -p /u/backscatter/ /u/offline/ /var/spool/backscatter/scan
chown -R scatter:scatter /u/backscatter/ /u/offline/ /var/spool/backscatter
```
10. Install a sudo configuration file for backscatter 
```bash
cp <git>/root/etc/sudoers.d/backscatter /etc/sudoers.d/backscatter
```
11. Install a rsyslog configuration files and reload rsyslog
```bash
cp <git>/root/etc/sudoers.d/backscatter /etc/sudoers.d/
cp <git>/root/etc/rsyslog.d/backscatter.conf /etc/rsyslog.d/
cp <git>/root/etc/rsyslog.d/audispd.conf /etc/rsyslog.d/
systemctl restart rsyslog.service
```

12. Create MySQL tables needed by backscatter
```sql 
mysql> create database backscatter;
mysql> CREATE TABLE `matches` (
 `id` int(11) NOT NULL AUTO_INCREMENT,
 `proto` varchar(20) COLLATE utf8_swedish_ci DEFAULT NULL,
 `srcip` varchar(100) COLLATE utf8_swedish_ci DEFAULT NULL,
 `srcport` varchar(10) COLLATE utf8_swedish_ci DEFAULT NULL,
 `dstip` varchar(100) COLLATE utf8_swedish_ci DEFAULT NULL,
 `dstport` varchar(10) COLLATE utf8_swedish_ci DEFAULT NULL,
 `reason` varchar(255) COLLATE utf8_swedish_ci DEFAULT NULL,
 `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 PRIMARY KEY (`id`),
 KEY `srcip` (`srcip`,`dstip`),
 KEY `dstport` (`dstport`),
 KEY `reason` (`reason`)
) ENGINE=MyISAM AUTO_INCREMENT=5373994 DEFAULT CHARSET=utf8 COLLATE=utf8_swedish_ci;
mysql> CREATE TABLE `state` (
 `srcip` varchar(100) COLLATE utf8_swedish_ci NOT NULL DEFAULT '',
 `dstip` varchar(100) COLLATE utf8_swedish_ci NOT NULL DEFAULT '',
 `hits` int(20) DEFAULT NULL,
 `comment` varchar(255) COLLATE utf8_swedish_ci DEFAULT NULL,
 `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 PRIMARY KEY (`srcip`,`dstip`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_swedish_ci;
```
13. Grant access to backscatter (daemon) and bracksmatter (web ui)
```sql
mysql> GRANT USAGE ON *.* TO 'backscatter'@'localhost' IDENTIFIED BY '<secret>';
mysql> GRANT ALL PRIVILEGES ON `backscatter`.* TO 'backscatter'@'localhost';
mysql> GRANT USAGE ON *.* TO 'bracksmatter'@'localhost' IDENTIFIED BY '<secret>';
mysql> GRANT SELECT ON `backscatter`.* TO 'bracksmatter'@'localhost';
```
14. Install a systemd unit files and start services
```bash
cp <git>/root/etc/systemd/system/anyip-listener.service /etc/systemd/system/
cp <git>/root/etc/systemd/system/backscatter.service /etc/systemd/system/
cp <git>/root/etc/systemd/system/report_backscatter.service /etc/systemd/system/
cp <git>/root/etc/systemd/system/feed-routes.service /etc/systemd/system/
cp <git>/root/etc/systemd/system/fifo.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable anyip-listener.service backscatter.service report_backscatter.service feed-routes.service fifo.service
systemctl start anyip-listener.service backscatter.service report_backscatter.service feed-routes.service fifo.service
```


