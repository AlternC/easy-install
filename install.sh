#!/bin/bash

### Configuration

. "lib_installer.sh"

if [ ! -f "config.sh" ] ; then

	cp config.sh.dist config.sh;

fi;

. "config.sh"

### Disclaimer 

misc "#################################################### Licence ###########
This script is licenced under the Gnu Public Licence v3.
You should have received a copy of the Licence, otherwise it is available
on https://www.gnu.org/copyleft/gpl.html. 
This script is  provided without warranty of any kind, either expressed 
or implied. In no event shall our juridical person be liable for any 
damages incsluding, but not limited to, direct, indirect, special, 
incidental or consequential damages or other losses arising out of the 
use of or inability to use our products.
... yada yada yada ..."

spacer

warn "#################################################### Warning ###########

This installation script for Alternc software is made for $ALTERNC_VERSION
running on $DEBIAN_VERSION $DEBIAN_VERSION_NUMBER.

It attempts at helping people willing to test or install Alternc for 
the first time and / or don't know so much about Linux, network etc.

Using this script will provide a working installation, but if you need 
something more specific you might prefer a custom installation.

To learn more about the choices made for this installer, please read 
http://www.alternc.org/simpleInstaller";

try_exit

spacer

### Environment info


if [[ $DEBUG == 1 ]] ; then

	warn "Debug mode activated."
	spacer

fi;


if [[ $DRY_RUN == 1 ]] ; then

	warn "Dry run mode activated."
	spacer

fi;

### Installer prequisites

## Checks debian / net / uid / etc. 

# Exits if user is not root
if [ $EUID != 0 ] ; then
	alert "You must be root, please authentificate with your user password or run as root";
fi;

# Exits if wrong debian or debian version
if [ ! -f /etc/debian_version ] ; then
	alert "Not a DEBIAN system (missing /etc/debian_version)"
fi
if [[ ! $(cat /etc/debian_version) =~ $DEBIAN_VERSION_NUMBER.[[:digit:]] ]] ; then
	alert "Not a valid DEBIAN system (not a $DEBIAN_VERSION $DEBIAN_VERSION_NUMBER)"
fi

# Exits if no web access
if ! ping -q -c 1 -W 3 $VAR_TEST_IP 2>&1 > /dev/null; then
    alert "This machine is not connected to Internet."
fi


## Debconf


# Installs dnsutils (mandatory for dig)
apt_get dnsutils
 
# Installs inetutils-ping 
apt_get inetutils-ping

# Installs pwgen password generator
apt_get pwgen




### User inputs

## DNS

# Asks if user wants to use the alternc services for DNS

info "Having Domain Name Servers is mandatory for your alternc instance.

Name servers are used to distribute informations about the domain names.

Don't know what that means? Or do not have name servers you can use?

We advice you to use the service provided by the alternc team.

This service is free. Learn more on http://alternc.net."

ask "Do you want to use Alternc.net name servers ? y/n"

read VAR_USE_ALTERNC_NS

check=$(validate $VAR_USE_ALTERNC_NS)


# User wants to use own name servers
if [[ "0" = "$check" ]] ; then
	info "You need two valid nameservers :"

	ask "  Please provide your primary NS server"
	read ALTERNC_NS1
	test_ns $ALTERNC_NS1
	
	ask "  Please provide your secondary NS server"
	read ALTERNC_NS2
	test_ns $ALTERNC_NS2
	
# User wants to use Alternc NS

else
	ALTERNC_NS1="ns1.alternc.net"
	ALTERNC_NS2="ns2.alternc.net"
fi


## URL 

spacer

info "The Alternc panel requires an URL for web access. If you own only 
one domaine name which is intended to be your own website, you 
should be careful about NOT choosing this domain name as the Alternc URL.

Simply create a subdomain dedicated to alternc like alternc.example.com

You can also choose to use a domain name provided by your hoster or 
directly the IP address of your server, but this is not a good solution.

Don't know much about DNS? The Alternc team  provides a free service 
for you: you get your own alternc.net subdomain, point it to this server
IP and use it as your Alternc panel URL."

ask "Would you like to use the free alternc.net panel subdomain name service?  y/n"

read VAR_USE_ALTERNC_SUBDOMAIN

check=$(validate $VAR_USE_ALTERNC_SUBDOMAIN)

# Wants to use own domain name
if [[ $check=0 ]] ; then

	ask "  Please provide your Alternc panel URL"
	read ALTERNC_DESKTOPNAME
	test_ns ALTERNC_DESKTOPNAME
	
 
# run the alterc.net api client
else
	alternc_net_get_domain
fi


## IP

spacer

info "Your Alternc server needs a public IP Address to be available on 
the web from everywhere in the world."

misc "For your information, here are the internet addresses of this machine:"

for ip in  $(ip addr show scope global | grep inet | cut -d' ' -f6 | cut -d/ -f1|tr '\n' ' '  ) ; do
	misc "   $ip"
done;

ask "Please provide the public IP address"

read ALTERNC_PUBLIC_IP

ALTERNC_INTERNAL_IP=$ALTERNC_PUBLIC_IP

# Checks if it works

test_local_ip $ALTERNC_PUBLIC_IP


## alternc modules 

# Asks if roundcube is required

spacer

info "
Roundcube is the webmail software proposed by alternc.

We recommand adding it to your installation.
"

ask "Would you like to install Roundcube? (y/n)"

read INSTALL_ROUNDCUBE

check=$(validate $INSTALL_ROUNDCUBE)

# User wants to add roundcube
if [[ -z $check ]] ; then

	SOURCES_USE_BACKPORTS=1
	ADDITIONAL_PACKAGES="$ADDITIONAL_PACKAGES alternc-roundcube"
	
fi

# Asks if mailman is required
spacer

info "
Mailman is the mailing list software proposed by alternc.
"

ask "Would you like to install Mailman? (y/n)"

read INSTALL_MAILMAN

check=$(validate $INSTALL_MAILMAN)

# User wants to add mailman
if [[ -z $check ]] ; then

	ADDITIONAL_PACKAGES="$ADDITIONAL_PACKAGES alternc-mailman"
	
fi



### Install alternc prerequisites

## FS 

# Installs acl
apt_get acl


# Instalsl quota
apt_get quota

# Backups fstab
misc "Editing and backuping your /etc/fstab file"
copy /etc/fstab /etc/fstab.bak

# Edits fstab

 
# Remounts "/" partition

mount -o remount /

# Checks if success


## Mysql

# Installs pwgen

apt_get pwgen

# Generates mysql server root password

MYSQL_ROOT_PASSWORD=$(pwgen -s 35)

# Stores mysql server root password in /root/.my.cnf
write "
[client]
password=$MYSQL_ROOT_PASSWORD
database=alternc" /root/.my.cnf 

# Preseeds mysql server root password
ALTERNC_MYSQL_PASSWORD=$MYSQL_ROOT_PASSWORD

debconf mysql-server/root_password password ${MYSQL_ROOT_PASSWORD} mysql-server-5.5
debconf mysql-server/root_password seen true mysql-server-5.5
debconf mysql-server/root_password_again password ${MYSQL_ROOT_PASSWORD} mysql-server-5.5
debconf mysql-server/root_password_again seen true mysql-server-5.5

# Inform the user
info "An important password has just been generated.

It is the mysql root (or master) password.

This password has been stored in the root directory : /root/.my.cnf

For your information this password is : "

warn "  $MYSQL_ROOT_PASSWORD"

# Installs mysql 
apt_get mysql-server mysql-client

# Checks if success : mysql service running 
check_service apache2

# Checks if success : root access to mysql
if [ -z $(mysql -uroot --password=$MYSQL_ROOT_PASSWORD -e "select * from mysql.user") ] ; then
	alert "Something went wrong: Mysql root password is invalid";
fi;

# Reset to null the mysql root password for now



## apt 

# Creates new sources file 

write "deb http://debian.alternc.org/ stable main
deb-src http://debian.alternc.org/ stable main" /etc/apt/sources.list.d/alternc.list


# Creates new sources file for backports if required

if [[ $SOURCES_USE_BACKPORTS = 1 ]] ; then 

	write "deb http://backports.debian.org/debian-backports wheezy-backports main contrib non-free" /etc/apt/sources.list.d/alternc.list

fi;

# Downloads key
wget http://debian.alternc.org/key.txt -O - | apt-key add - 

# Updates
apt-get update

# Checks list success
if [ -z $(apt-cache search alternc) ] ; then 
	alert "Something went wrong, could not find the alternc package in the sources";
fi;


### debconf 

# Preseeds debconf variables

debconf alternc/acluninstalled "$ALTERNC_ACLUNINSTALLED"
debconf alternc/quotauninstalled "$ALTERNC_QUOTAUNINSTALLED"
debconf alternc/desktopname "$ALTERNC_DESKTOPNAME"
debconf alternc/hostingname "$ALTERNC_HOSTINGNAME"
debconf alternc/ns1 "$ALTERNC_NS1"
debconf alternc/ns2 "$ALTERNC_NS2"
debconf alternc/alternc_html "$ALTERNC_ALTERNC_HTML"
debconf alternc/alternc_mail "$ALTERNC_ALTERNC_MAIL"
debconf alternc/alternc_logs "$ALTERNC_ALTERNC_LOGS"
debconf alternc/mysql/host "$ALTERNC_MYSQL_HOST"
debconf alternc/mysql/db "$ALTERNC_MYSQL_DB"
debconf alternc/mysql/user "$ALTERNC_MYSQL_USER"
debconf alternc/mysql/remote_user "$ALTERNC_MYSQL_REMOTE_USER"
debconf alternc/mysql/password "$ALTERNC_MYSQL_PASSWORD"
debconf alternc/mysql/remote_password "$ALTERNC_MYSQL_REMOTE_PASSWORD"
debconf alternc/mysql/alternc_mail_user "$ALTERNC_MYSQL_ALTERNC_MAIL_USER"
debconf alternc/mysql/alternc_mail_password "$ALTERNC_MYSQL_ALTERNC_MAIL_PASSWORD"
debconf alternc/mysql/client "$ALTERNC_MYSQL_CLIENT"
debconf alternc/sql/backup_type "$ALTERNC_SQL_BACKUP_TYPE"
debconf alternc/sql/backup_overwrite "$ALTERNC_SQL_BACKUP_OVERWRITE"
debconf alternc/public_ip "$ALTERNC_PUBLIC_IP"
debconf alternc/internal_ip "$ALTERNC_INTERNAL_IP"
debconf alternc/default_mx "$ALTERNC_DEFAULT_MX"
debconf alternc/default_mx2 "$ALTERNC_DEFAULT_MX2"
debconf alternc/alternc_location "$ALTERNC_ALTERNC_LOCATION"
debconf alternc/monitor_ip "$ALTERNC_MONITOR_IP"
debconf alternc/postrm_remove_databases "$ALTERNC_POSTRM_REMOVE_DATABASES"
debconf alternc/postrm_remove_datafiles "$ALTERNC_POSTRM_REMOVE_DATAFILES"
debconf alternc/postrm_remove_bind "$ALTERNC_POSTRM_REMOVE_BIND"
debconf alternc/postrm_remove_mailboxes "$ALTERNC_POSTRM_REMOVE_MAILBOXES"
debconf alternc/slaves "$ALTERNC_SLAVES"
debconf alternc/use_local_mysql "$ALTERNC_USE_LOCAL_MYSQL"
debconf alternc/use_remote_mysql "$ALTERNC_USE_REMOTE_MYSQL"
debconf alternc/retry_remote_mysql "$ALTERNC_RETRY_REMOTE_MYSQL"
debconf alternc/use_private_ip "$ALTERNC_USE_PRIVATE_IP"
debconf alternc/remote_mysql_error "$ALTERNC_REMOTE_MYSQL_ERROR"

### Alternc install

# Starts the alternc install 

apt_get alternc $ADDITIONAL_PACKAGES

### Post install

# Run the alternc.install script
if [ ! -f /usr/lib/alternc/alternc.install ] ; then 
	alert "Something went wrong with your installation : alternc.install script  not found."
fi;

# Checks if success : Apache2 running 
check_service apache2

# Checks if success : Status 200 on panel home + title 

# Checks if success : Postfix service running
check_service postfix

# Checks if success : xxx running
