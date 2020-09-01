#!/bin/bash


### Configuration

# Exit if any error occurs
if [[ $STRICT == 1 ]] ; then
    set -e
fi;

# Gettext is a hard dependancy, install it "raw style"
echo "Installing gettext for translations"
which gettext &>/dev/null || apt-get install --force-yes -y gettext || { echo "[!] Exit: Failed to install gettext"; exit 1; }

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

This installation script helps to test or install AlternC for 
the first time and / or don't know so much about Linux, network etc.

Using this script will provide a working installation, but if you need 
something more specific you might prefer a custom installation.

To learn more about the choices made for this installer, please read 
http://www.alternc.org/simpleInstaller" 

try_exit

spacer

### Environment info

# Is debug mode ON?
if [[ $DEBUG == 1 ]] ; then
    misc "Debug mode activated."
fi;

# Is dry run mode ON?
if [[ $DRY_RUN == 1 ]] ; then
    misc "Dry run mode activated."
fi;

# Is silent mode ON?
if [[ "$SILENT" == 1 ]] ; then
    misc "Silent mode activated."
    export DEBIAN_FRONTEND=noninteractive
fi;

### Installer prequisites

## Mandatory packets
misc "Installing mandatory packages"
 
# Installs various packages required to work
apt_get apache2 apache2-bin libapache2-mpm-itk dnsutils lsb-release inetutils-ping pwgen gnupg2

# Manually disable mpm event
a2dismod mpm_event 

## Checks debian / net / uid / etc. 

# Exits if user is not root
if [ $EUID != 0 ] ; then
    alert "You must be root, please authentificate with your user password or run as root";
fi;

# Exits if not debian
if [ ! -f /etc/debian_version ] ; then
    alert "Not a DEBIAN system (missing /etc/debian_version)"
fi

DEBIAN_RELEASE=$(lsb_release -cs)

# Exits if alternc present 

if [[ $(dpkg-query -W -f='${Status}' alternc 2>/dev/null | grep -c "ok installed") == 1 ]] ; then 
    alert "AlternC already installed, nothing to do." ; 
fi;


### User inputs

## IP

spacer

info "=====        Your AlternC server needs a public IP Address         =====

This makes it available on the web from everywhere in the world."

misc "For your information, here are the internet addresses of this machine:"

for ip in  $(ip addr show scope global | grep inet | cut -d' ' -f6 | cut -d/ -f1|tr '\n' ' '  ) ; do
    warn "$ip"
done;

ask "Please provide the public IP address"

if [[ "$SILENT" != 1 ]] ;
    then read ALTERNC_PUBLIC_IP
    else if [[ -z $ALTERNC_PUBLIC_IP ]] ; then
        alert "Missing variable %s for silent install" "ALTERNC_PUBLIC_IP"
    fi
fi;

ALTERNC_INTERNAL_IP=$ALTERNC_PUBLIC_IP

# Checks if it works
# It is allowed. Maybe only warn @todo
#test_local_ip $ALTERNC_PUBLIC_IP


## FQDN

#### spacer
#### 
#### info "=====              Your AlternC needs a domain name                =====
#### 
#### This domain name will be used to access the panel and send/receive mail.
####                                          
#### You must use an original domain name dedicated for this purpose.
#### In other words, do not use a domain name intended to be your company or 
#### personal website. 
#### For example, 'example.com' is not good, unless your company is the 
#### hosting service by itself. 'panel.example.com' will work better, 
#### allowing you to still have your website on 'www.example.com'
#### 
#### If you are unsure, here are a few solutions: 
#### 1.  Create a subdomain dedicated to AlternC on a domain name you own
#### 2.  Use the free AlternC.net domain name service      
####         
#### We recommand using the AlternC.net subdomain name if you are new to this.
#### You'll only need to request your subdomain on http://www.alternc.net and 
#### point it to the IP address you just provided.
#### Your AlternC domain name might then look like 'example.alternc.net'"
#### 
#### ask "Do you want to use AlternC.net domain name service? (Y/n)"
#### 
#### if [[ "$SILENT" != 1 ]] ;
####     then read VAR_USE_ALTERNC_SUBDOMAIN
####     else if [[ -z $VAR_USE_ALTERNC_SUBDOMAIN ]] ; then
####         alert "Missing variable %s for silent install" "VAR_USE_ALTERNC_SUBDOMAIN"
####     fi
#### fi;
#### 
#### check=$(validate $VAR_USE_ALTERNC_SUBDOMAIN)
#### 
#### # Wants to use own domain name
#### if [[ $check=0 ]] ; then

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
    
    ask "  Please provide your AlternC domain name"
if [[ "$SILENT" != 1 ]] ;
    then read ALTERNC_DESKTOPNAME
    else if [[ -z $ALTERNC_DESKTOPNAME ]] ; then
        alert "Missing variable %s for silent install" "ALTERNC_DESKTOPNAME"
    fi
fi;
    #test_ns "$ALTERNC_DESKTOPNAME"
    
 
#### # run the alterc.net api client
#### else
####     #todo 
####     alternc_net_get_domain
#### 
####     ask "Please provide the AlternC.net subdomain name:"
####     if [[ "$SILENT" != 1 ]] ;
####         then read ALTERNC_DESKTOPNAME
####         else if [[ -z $ALTERNC_DESKTOPNAME ]] ; then
####             alert "Missing variable %s for silent install" "ALTERNC_DESKTOPNAME"
####         fi
####     fi;
####     test_ns "$ALTERNC_DESKTOPNAME"
####     
#### fi

# Sets the mailname 
ALTERNC_POSTFIX_MAILNAME="$ALTERNC_DESKTOPNAME"

# Writes the mailname in file
write "$ALTERNC_DESKTOPNAME" /etc/mailname 0

# Edit the host file
backup_file "/etc/hosts"
insert /etc/hosts 2 "::1\t$ALTERNC_DESKTOPNAME"
insert /etc/hosts 2 "127.0.0.1\t$ALTERNC_DESKTOPNAME"


## DNS

# Asks if user wants to use the AlternC services for DNS

info "=====              Your AlternC needs DNS Servers                =====

Domain Name Servers announce addresses of the domain names on the web.

If you don't have at least two name servers with minimal redundancy, we
highly recommand you the free service we provide (see http://alternc.net )"

ask "Do you want to use AlternC.net name servers ?(Y/n)"

if [[ "$SILENT" != 1 ]] ;
    then read VAR_USE_ALTERNC_NS
    else if [[ -z $VAR_USE_ALTERNC_NS ]] ; then
        alert "Missing variable %s for silent install" "VAR_USE_ALTERNC_NS"
    fi
fi;

check=$(validate $VAR_USE_ALTERNC_NS)


# User wants to use own name servers
if [[ "$check" == "0" ]] ; then
    info "You need two valid nameservers :"

    ask "  Please provide your primary NS server"
    if [[ "$SILENT" != 1 ]] ;
        then read ALTERNC_NS1
        else if [[ -z $ALTERNC_NS1 ]] ; then
            alert "Missing variable %s for silent install" "ALTERNC_NS1"
        fi
    fi;
    test_ns $ALTERNC_NS1
    
    ask "  Please provide your secondary NS server"
    if [[ "$SILENT" != 1 ]] ;
        then read ALTERNC_NS2
        else if [[ -z $ALTERNC_NS2 ]] ; then
            alert "Missing variable %s for silent install" "ALTERNC_NS2"
        fi
    fi;
    test_ns $ALTERNC_NS2
    
# User wants to use AlternC NS

else
    ALTERNC_NS1="ns1.alternc.net"
    ALTERNC_NS2="ns2.alternc.net"
fi




## AlternC modules 

# Asks if roundcube is required

#### spacer
#### 
#### info "
#### =====           Optional installation: roundcube webmail           =====
#### 
#### Roundcube is the webmail software proposed by AlternC.
#### 
#### We recommand adding it to your installation.
#### "
#### 
#### ask "Would you like to install Roundcube? (Y/n)"
#### 
#### if [[ "$SILENT" != 1 ]] ;
####     then read INSTALL_ROUNDCUBE
####     else if [[ -z $INSTALL_ROUNDCUBE ]] ; then
####         alert "Missing variable %s for silent install" "INSTALL_ROUNDCUBE"
####     fi
#### fi;
#### 
#### check=$(validate $INSTALL_ROUNDCUBE)
#### 
#### # User wants to add roundcube
#### if [[ "$check" == 1 ]] ; then
#### 
####     SOURCES_USE_BACKPORTS=1
####     ADDITIONAL_PACKAGES+=(alternc-roundcube)
####     info "Roundcube added to your configuration"
####     
#### fi
#### 
#### # Asks if mailman is required
#### spacer
#### 
#### info "
#### =====      Optional installation: mailman mailing list manager     =====
#### 
#### Mailman is the mailing list software proposed by AlternC.
#### "
#### 
#### ask "Would you like to install Mailman? (Y/n)"
#### 
#### if [[ "$SILENT" != 1 ]] ;
####     then read INSTALL_MAILMAN
####     else if [[ -z $INSTALL_MAILMAN ]] ; then
####         alert "Missing variable %s for silent install" "INSTALL_MAILMAN"
####     fi
#### fi;
#### 
#### check=$(validate $INSTALL_MAILMAN)
#### 
#### # User wants to add mailman
#### if [[ "$check" == 1 ]] ; then
#### 
####     ADDITIONAL_PACKAGES+=(alternc-mailman)
####     
####     info "Mailman added to your configuration"
####     
####     # Asks language
####     misc "By default mailman is installed with french and english."
####     ask "Do you want to use french as default language? (Y/n)"
####     read MAILMAN_USE_FRENCH
####     check=$(validate $MAILMAN_USE_FRENCH)    
####     
####     # Switches default mailman language to english
####     if [[ $check == 0 ]] ; then
####         ALTERNC_MAILMAN_DEFAULT_SERVER_LANGUAGE="en"
####     fi;
####     
#### fi

### Mysql password

# Generates phpmyadmin user password
ALTERNC_PHPMYADMIN_USERPASSWORD=$(pwgen -s 15)

# Generates mysql server root password
MYSQL_ROOT_PASSWORD=$(pwgen -s 35)

# Stores mysql server root password in /root/.my.cnf
write "
[client]
password=$MYSQL_ROOT_PASSWORD
database=alternc" /root/.my.cnf 

ALTERNC_MYSQL_PASSWORD=$MYSQL_ROOT_PASSWORD

### Debconf parameters


# alternC
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
debconf alternc/mysql/password string "$MYSQL_ROOT_PASSWORD"
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

# mailman
debconf alternc-mailman/patch-mailman string "$ALTERNC_MAILMAN_PATCH_MAILMAN" alternC-mailman
debconf mailman/site_languages string "$ALTERNC_MAILMAN_SITE_LANGUAGES" mailman
debconf mailman/used_languages string "$ALTERNC_MAILMAN_USED_LANGUAGES" mailman
debconf mailman/default_server_language string "$ALTERNC_MAILMAN_DEFAULT_SERVER_LANGUAGE" mailman
debconf mailman/create_site_list string "$ALTERNC_MAILMAN_CREATE_SITE_LIST" mailman

# phpmyadmin
debconf phpmyadmin/reconfigure-webserver string $ALTERNC_PHPMYADMIN_WEBSERVER phpmyadmin
debconf phpmyadmin/dbconfig-install string "$ALTERNC_PHPMYADMIN_DBCONFIG" phpmyadmin
debconf phpmyadmin/mysql/admin-user string "$ALTERNC_PHPMYADMIN_ADMINUSER" phpmyadmin
debconf phpmyadmin/mysql/admin-pass string "$MYSQL_ROOT_PASSWORD" phpmyadmin
debconf phpmyadmin/setup-username string "$ALTERNC_PHPMYADMIN_USERNAME" phpmyadmin
debconf phpmyadmin/setup-password string "$ALTERNC_PHPMYADMIN_USERPASSWORD" phpmyadmin
debconf phpmyadmin/password-confirm string "$ALTERNC_PHPMYADMIN_USERPASSWORD" phpmyadmin

# postfix
debconf postfix/mailname string $ALTERNC_POSTFIX_MAILNAME postfix
debconf postfix/main_mailer_type string $ALTERNC_POSTFIX_MAILERTYPE postfix

# proftpd
debconf shared/proftpd/inetd_or_standalone string $ALTERNC_PROFTPD_STANDALONE proftpd-basic

# mysql
debconf mysql-server/root_password string "$MYSQL_ROOT_PASSWORD" mysql-server-5.5
debconf mysql-server/root_password_again string "$MYSQL_ROOT_PASSWORD" mysql-server-5.5

## dbconfig-commmon

# We deploy a phpmyadmin conf file 

copy "templates/phpmyadmin.conf" "/etc/dbconfig-common/phpmyadmin.conf"
replace "%ALTERNC_PHPMYADMIN_USERPASSWORD%" "$ALTERNC_PHPMYADMIN_USERPASSWORD" "/etc/dbconfig-common/phpmyadmin.conf"


### Install AlternC prerequisites


## FS 

# Installs acl quota
apt_get acl quota

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
apt_get mariadb-server mariadb-client


## apt sources, allows nightly
ALTERNC_SOURCE_LIST_FILE="/etc/apt/sources.list.d/alternc.list" 
# If nightly 
if [ "$NIGHTLY" == "1" ]; then
    ALTERNC_SOURCE_TEMPLATE="templates/$DEBIAN_RELEASE/alternc-easy-install-nightly.list"
    ALTERNC_SOURCE_KEY_FILE="templates/$DEBIAN_RELEASE/nightly.key"
else 
    ALTERNC_SOURCE_TEMPLATE="templates/$DEBIAN_RELEASE/alternc-easy-install.list"
    ALTERNC_SOURCE_KEY_FILE="templates/$DEBIAN_RELEASE/alternc.key"
fi

# Sets backport source file
BACKPORTS_SOURCE_LIST_FILE="/etc/apt/sources.list.d/backports-easy-install.list" 
BACKPORTS_SOURCE_TEMPLATE="templates/$DEBIAN_RELEASE/backports-easy-install.list" 

# Delete source files if exist 
delete "$ALTERNC_SOURCE_LIST_FILE"
delete "$BACKPORTS_SOURCE_LIST_FILE"

# Creates new debian sources file 
copy $ALTERNC_SOURCE_TEMPLATE "$ALTERNC_SOURCE_LIST_FILE"

# Creates new  backports sources file if required
# if [[ "$SOURCES_USE_BACKPORTS" = 1 ]] ; then 
    copy "$BACKPORTS_SOURCE_TEMPLATE" $BACKPORTS_SOURCE_LIST_FILE
#fi;

# Downloads key
wget $(cat "$ALTERNC_SOURCE_KEY_FILE") -O - | apt-key add - 

# Updates
apt-get update

# Checks list success
if [[ -z $(apt-cache search alternc) ]] ; then 
    alert "Something went wrong, could not find the AlternC package in the sources";
fi;


### AlternC install

# dirty fix for buster
apt_get -t ${DEBIAN_RELEASE}-backports phpmyadmin php-twig

# Starts the AlternC install 
apt_get alternc alternc-certbot

# Adds additional packages if required
if [[ $ADDITIONAL_PACKAGES != "" ]] ; then  
    apt_get -t ${DEBIAN_RELEASE}-backports ${ADDITIONAL_PACKAGES[@]}
fi;

### Post install

# Run the alternc.install script
info "Running the alternc.install script"
if [[ ! -f /usr/share/alternc/install/alternc.install ]] ; then 
    alert "Something went wrong with your installation : alternc.install script  not found."
else 
alternc.install
fi

## mysql


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

# Checks if success : mysql service running 
check_service mysqld

# Checks if success : xxx running

## @todo

# Updates admin password
RND="`echo -n $RANDOM $RANDOM $RANDOM`"
/usr/bin/mysql alternc -e "UPDATE membres SET pass=ENCRYPT('$MYSQL_ROOT_PASSWORD',CONCAT('\$1\$',MD5('$RND'))) WHERE uid='2000'"
if [ $? -eq 0 ] ; then
    ALTERNC_ADMIN_PASSWORD=$MYSQL_ROOT_PASSWORD
else
    ALTERNC_ADMIN_PASSWORD="admin"
    warn "Caution! Failed to update the default password, change it on first login for security reasons!"
fi

# Prints passwords 

spacer 

info "You can now visit your AlternC on http://%s" $ALTERNC_DESKTOPNAME

warn "You should authentificate with login: admin/%s" $ALTERNC_ADMIN_PASSWORD

# Proposes to send passwords by email

## @todo


