#!/bin/bash


### Configuration

# Exit if any error occurs
if [[ $STRICT == 1 ]] ; then
	set -e
fi;

# Functions 
. "lib_installer.sh"

# Local config
if [ ! -f "config.sh" ] ; then
    cp config.sh.dist config.sh;
fi;
source "config.sh"

### Disclaimer 

misc "=====                           Licence                            =====

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

warn "=====                           Warning                            =====

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


## Mandatory packets

misc "Installing mandatory packages"

# Installs dnsutils (mandatory for dig)
apt_get dnsutils
 
# Installs inetutils-ping 
apt_get inetutils-ping

# Installs pwgen password generator
apt_get pwgen


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

# Exits if alternc present 

if [[ $(dpkg-query -W -f='${Status}' alternc 2>/dev/null | grep -c "ok installed") == 1 ]] ; then 
	alert "Alternc already installed, nothing to do." ; 
fi;


### User inputs

## IP

spacer

info "=====        Your Alternc server needs a public IP Address         =====

This makes it available on the web from everywhere in the world."

misc "For your information, here are the internet addresses of this machine:"

for ip in  $(ip addr show scope global | grep inet | cut -d' ' -f6 | cut -d/ -f1|tr '\n' ' '  ) ; do
    warn "$ip"
done;

ask "Please provide the public IP address"

read ALTERNC_PUBLIC_IP

ALTERNC_INTERNAL_IP=$ALTERNC_PUBLIC_IP

# Checks if it works

test_local_ip $ALTERNC_PUBLIC_IP


## FQDN

spacer

info "=====              Your Alternc needs a domain name                =====

This domain name will be used to access the panel and send/receive mail.
                                         
You must use an original domain name dedicated for this purpose.
In other words, do not use a domain name intended to be your company or 
personal website. 
For example, 'example.com' is not good, unless your company is the 
hosting service by itself. 'panel.example.com' will work better, 
allowing you to still have your website on 'www.example.com'

If you are unsure, here are a few solutions: 
1.  Create a subdomain dedicated to alternc on a domain name you own
2.  Use the free alternc.net domain name service      
        
We recommand using the alternc.net subdomain name if you are new to this.
You'll only need to request your subdomain on http://alternc.net and 
point it to the IP address you just provided.
Your alternc domain name might then look like 'example.alternc.net'"

ask "Do you want to use alternc.net domain name service? (y/N)"

read VAR_USE_ALTERNC_SUBDOMAIN

check=$(validate $VAR_USE_ALTERNC_SUBDOMAIN)

# Wants to use own domain name
if [[ $check=0 ]] ; then

    # Reads the hostname
    if [ -f /etc/hostname ] ; then
        HOSTNAME=$(cat /etc/hostname)
        misc "  For your information, this server hostname is :
  $HOSTNAME"
    fi;
    # Reads the mailname
    if [ -f /etc/mailname ] ; then
        MAILNAME=$(cat /etc/mailname)
        misc "  For your information, this server mailname is :
  $MAILNAME"
    fi;
    
    ask "  Please provide your Alternc domain name"
    read ALTERNC_DESKTOPNAME
    test_ns "$ALTERNC_DESKTOPNAME"
    
 
# run the alterc.net api client
else
	#todo 
    alternc_net_get_domain

    ask "Please provide the alternc.net subdomain name:"
    read ALTERNC_DESKTOPNAME
    test_ns "$ALTERNC_DESKTOPNAME"
    
fi

# Sets the mailname 
ALTERNC_POSTFIX_MAILNAME="$ALTERNC_DESKTOPNAME"

# Writes the mailname in file
write "$ALTERNC_DESKTOPNAME" /etc/mailname 0

# Edit the host file
backup_file "/etc/hosts"
insert /etc/hosts 2 "::1\t$ALTERNC_DESKTOPNAME"
insert /etc/hosts 2 "127.0.0.1\t$ALTERNC_DESKTOPNAME"


## DNS

# Asks if user wants to use the alternc services for DNS

info "=====              Your Alternc needs DNS Servers                =====

Domain Name Servers announce addresses of the domain names on the web.

If you don't have at least two name servers with minimal redundancy, we
highly recommand you the free service we provide (see http://alternc.net )"

ask "Do you want to use Alternc.net name servers ?(y/N)"

read VAR_USE_ALTERNC_NS

check=$(validate $VAR_USE_ALTERNC_NS)


# User wants to use own name servers
if [[ "$check" == "0" ]] ; then
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




## alternc modules 

# Asks if roundcube is required

spacer

info "
=====           Optional installation: roundcube webmail           =====

Roundcube is the webmail software proposed by alternc.

We recommand adding it to your installation.
"

ask "Would you like to install Roundcube? (y/N)"

read INSTALL_ROUNDCUBE

check=$(validate $INSTALL_ROUNDCUBE)

# User wants to add roundcube
if [[ "$check" == 1 ]] ; then

    SOURCES_USE_BACKPORTS=1
    ADDITIONAL_PACKAGES="$ADDITIONAL_PACKAGES alternc-roundcube"
    info "Roundcube added to your configuration"
    
fi

# Asks if mailman is required
spacer

info "
=====      Optional installation: mailman mailing list manager     =====

Mailman is the mailing list software proposed by alternc.
"

ask "Would you like to install Mailman? (y/N)"

read INSTALL_MAILMAN

check=$(validate $INSTALL_MAILMAN)

# User wants to add mailman
if [[ "$check" == 1 ]] ; then

    ADDITIONAL_PACKAGES="$ADDITIONAL_PACKAGES alternc-mailman"
    
    info "Mailman added to your configuration"
    
    # Asks language
    misc "By default mailman is installed with french and english."
    ask "Do you want to use french as default language? (y/N)"
	read MAILMAN_USE_FRENCH
	check=$(validate $MAILMAN_USE_FRENCH)    
	
	# Switches default mailman language to english
	if [[ $check == 0 ]] ; then
		ALTERNC_MAILMAN_DEFAULT_SERVER_LANGUAGE="en"
	fi;
    
fi



### Debconf parameters


# alternc

debconf alternc/acluninstalled string "$ALTERNC_ACLUNINSTALLED"
debconf alternc/quotauninstalled string "$ALTERNC_QUOTAUNINSTALLED"
debconf alternc/desktopname string "$ALTERNC_DESKTOPNAME"
debconf alternc/hostingname string "$ALTERNC_HOSTINGNAME"
debconf alternc/ns1 string "$ALTERNC_NS1"
debconf alternc/ns2 string "$ALTERNC_NS2"
debconf alternc/alternc_html string "$ALTERNC_ALTERNC_HTML"
debconf alternc/alternc_mail string "$ALTERNC_ALTERNC_MAIL"
debconf alternc/alternc_logs string "$ALTERNC_ALTERNC_LOGS"
debconf alternc/mysql/host string "$ALTERNC_MYSQL_HOST"
debconf alternc/mysql/db string "$ALTERNC_MYSQL_DB"
debconf alternc/mysql/user string "$ALTERNC_MYSQL_USER"
debconf alternc/mysql/remote_user string "$ALTERNC_MYSQL_REMOTE_USER"
debconf alternc/mysql/password string "$ALTERNC_MYSQL_PASSWORD"
debconf alternc/mysql/remote_password string "$ALTERNC_MYSQL_REMOTE_PASSWORD"
debconf alternc/mysql/alternc_mail_user string "$ALTERNC_MYSQL_ALTERNC_MAIL_USER"
debconf alternc/mysql/alternc_mail_password string "$ALTERNC_MYSQL_ALTERNC_MAIL_PASSWORD"
debconf alternc/mysql/client string "$ALTERNC_MYSQL_CLIENT"
debconf alternc/sql/backup_type string "$ALTERNC_SQL_BACKUP_TYPE"
debconf alternc/sql/backup_overwrite string "$ALTERNC_SQL_BACKUP_OVERWRITE"
debconf alternc/public_ip string "$ALTERNC_PUBLIC_IP"
debconf alternc/internal_ip string "$ALTERNC_INTERNAL_IP"
debconf alternc/default_mx string "$ALTERNC_DEFAULT_MX"
debconf alternc/default_mx2 string "$ALTERNC_DEFAULT_MX2"
debconf alternc/alternc_location string "$ALTERNC_ALTERNC_LOCATION"
debconf alternc/monitor_ip string "$ALTERNC_MONITOR_IP"
debconf alternc/postrm_remove_databases string "$ALTERNC_POSTRM_REMOVE_DATABASES"
debconf alternc/postrm_remove_datafiles string "$ALTERNC_POSTRM_REMOVE_DATAFILES"
debconf alternc/postrm_remove_bind string "$ALTERNC_POSTRM_REMOVE_BIND"
debconf alternc/postrm_remove_mailboxes string "$ALTERNC_POSTRM_REMOVE_MAILBOXES"
debconf alternc/slaves string "$ALTERNC_SLAVES"
debconf alternc/use_local_mysql string "$ALTERNC_USE_LOCAL_MYSQL"
debconf alternc/use_remote_mysql string "$ALTERNC_USE_REMOTE_MYSQL"
debconf alternc/retry_remote_mysql string "$ALTERNC_RETRY_REMOTE_MYSQL"
debconf alternc/use_private_ip string "$ALTERNC_USE_PRIVATE_IP"
debconf alternc/remote_mysql_error string "$ALTERNC_REMOTE_MYSQL_ERROR"

# others
debconf alternc-mailman/patch-mailman string "$ALTERNC_MAILMAN_PATCH_MAILMAN" alternc-mailman
debconf mailman/site_languages string "$ALTERNC_MAILMAN_SITE_LANGUAGES" mailman
debconf mailman/used_languages string "$ALTERNC_MAILMAN_USED_LANGUAGES" mailman
debconf mailman/default_server_language string "$ALTERNC_MAILMAN_DEFAULT_SERVER_LANGUAGE" mailman
debconf mailman/create_site_list string "$ALTERNC_MAILMAN_CREATE_SITE_LIST" mailman
debconf phpmyadmin/reconfigure-webserver string $ALTERNC_PHPMYADMIN_WEBSERVER phpmyadmin
debconf phpmyadmin/dbconfig-install string $ALTERNC_PHPMYADMIN_DBCONFIG phpmyadmin
debconf postfix/mailname string $ALTERNC_POSTFIX_MAILNAME postfix
debconf postfix/main_mailer_type string $ALTERNC_POSTFIX_MAILERTYPE postfix
debconf shared/proftpd/inetd_or_standalone string $ALTERNC_PROFTPD_STANDALONE proftpd-basic

# preseeds mysql
debconf mysql-server/root_password string password "" mysql-server-5.5
debconf mysql-server/root_password_again string password "" mysql-server-5.5

### Install alternc prerequisites


## FS 

# Installs acl
apt_get acl

# Install quota
apt_get quota

# Backups fstab
misc "Editing and backuping your /etc/fstab file"
backup_file /etc/fstab 

# Edits fstab
fstab_quota_and_acl
 
# Remounts "/" partition
mount -o remount /

# Checks if success

# @todo

## postfix

# Installs postfix

apt_get postfix postfix-mysql


## Mysql


# Installs mysql 
apt_get mysql-server mysql-client

# Checks if success : mysql service running 
check_service mysqld


## apt 
ALTERNC_SOURCE_LIST_FILE="/etc/apt/sources.list.d/alternc-easy-install.list" 
BACKPORTS_SOURCE_LIST_FILE="/etc/apt/sources.list.d/backports-easy-install.list" 

# delete source files if exist 
delete $ALTERNC_SOURCE_LIST_FILE
delete $BACKPORTS_SOURCE_LIST_FILE

# Creates new debian sources file 
write "deb http://debian.alternc.org/ stable main
deb-src http://debian.alternc.org/ stable main" $ALTERNC_SOURCE_LIST_FILE

# Creates new  backports sources file if required
if [[ $SOURCES_USE_BACKPORTS = 1 ]] ; then 
    write "deb http://http.debian.net/debian wheezy-backports main" $BACKPORTS_SOURCE_LIST_FILE
fi;

# Downloads key
wget http://debian.alternc.org/key.txt -O - | apt-key add - 

# Updates
apt-get update

# Checks list success
if [[ -z $(apt-cache search alternc) ]] ; then 
    alert "Something went wrong, could not find the alternc package in the sources";
fi;


### Alternc install

# Starts the alternc install 
apt_get alternc 

# Adds additional packages if required
if [[ $ADDITIONAL_PACKAGES != "" ]] ; then  
	apt_get -t squeeze-backports $ADDITIONAL_PACKAGES
fi;

### Post install

# Run the alternc.install script
info "Running the alternc.install script"
if [[ ! -f /usr/share/alternc/install/alternc.install ]] ; then 
    alert "Something went wrong with your installation : alternc.install script  not found."
fi;
alternc.install

## mysql

# Generates mysql server root password
MYSQL_ROOT_PASSWORD=$(pwgen -s 35)

# Sets the real mysql root password 
info "Resetting the mysql password"
mysql -u root --password="" -e "UPDATE mysql.user SET Password=PASSWORD('$MYSQL_ROOT_PASSWORD') WHERE user.User = 'root' LIMIT 1;"
info "Flush mysql privileges"
mysql -u root --password="" -e "FLUSH PRIVILEGES;"

# Stores mysql server root password in /root/.my.cnf
write "
[client]
password=$MYSQL_ROOT_PASSWORD
database=alternc" /root/.my.cnf 

# Inform the user
info "An important password has just been generated.

It is the mysql root (or master) password.

This password has been stored in the root directory : /root/.my.cnf

For your information this password is : "

warn "  $MYSQL_ROOT_PASSWORD"

## Service checks

# Checks if success : Apache2 running 
check_service apache2

# Checks if success : Status 200 on panel home + title 

# Checks if success : Postfix service running
check_service master

# Checks if success : xxx running

# Prints passwords 

# Proposes to send passwords by email



