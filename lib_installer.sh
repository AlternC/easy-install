# Colors
COL_GRAY="\x1b[30;01m"
COL_RED="\x1b[31;01m"
COL_GREEN="\x1b[32;01m"
COL_YELLOW="\x1b[33;01m"
COL_BLUE="\x1b[34;01m"
COL_PURPLE="\x1b[35;01m"
COL_CYAN="\x1b[36;01m"
COL_WHITE="\x1b[37;01m"
COL_RESET="\x1b[39;49;00m"

E_CDERROR=65

#AlternC variables
ALTERNC_ACLUNINSTALLED=""
ALTERNC_ALTERNC_HTML=/var/www/alternc
ALTERNC_ALTERNC_LOCATION=/var/alternc
ALTERNC_ALTERNC_LOGS=/var/log/alternc/sites/
ALTERNC_ALTERNC_MAIL=/var/mail/alternc
ALTERNC_DEFAULT_MX2=""
ALTERNC_DEFAULT_MX=""
ALTERNC_DESKTOPNAME=""
ALTERNC_HOSTINGNAME=AlternC
ALTERNC_INTERNAL_IP=""
ALTERNC_MONITOR_IP="127.0.0.1"
ALTERNC_MYSQL_ALTERNC_MAIL_PASSWORD=""
ALTERNC_MYSQL_ALTERNC_MAIL_USER=""
ALTERNC_MYSQL_CLIENT=localhost
ALTERNC_MYSQL_DB=alternc
ALTERNC_MYSQL_HOST="127.0.0.1"
ALTERNC_MYSQL_PASSWORD="" # Set during install
ALTERNC_MYSQL_REMOTE_PASSWORD=""
ALTERNC_MYSQL_REMOTE_USER=""
ALTERNC_MYSQL_USER=root
ALTERNC_NS1=""
ALTERNC_NS2=""
ALTERNC_POP_BEFORE_SMTP_WARNING=""
ALTERNC_POSTRM_REMOVE_BIND=""
ALTERNC_POSTRM_REMOVE_DATABASES=""
ALTERNC_POSTRM_REMOVE_DATAFILES=""
ALTERNC_POSTRM_REMOVE_MAILBOXES=""
ALTERNC_PUBLIC_IP=""
ALTERNC_QUOTAUNINSTALLED=false
ALTERNC_REMOTE_MYSQL_ERROR=""
ALTERNC_SLAVES=""
ALTERNC_SQL_BACKUP_OVERWRITE=no
ALTERNC_SQL_BACKUP_TYPE=rotate
ALTERNC_USE_LOCAL_MYSQL=true
ALTERNC_USE_PRIVATE_IP=""
ALTERNC_USE_REMOTE_MYSQL=""
ALTERNC_WELCOMECONFIRM=true



# Some variables defined per design for the user
ALTERNC_MAILMAN_SITE_LANGUAGES="fr, en"
ALTERNC_MAILMAN_DEFAULT_SERVER_LANGUAGE="fr"
ALTERNC_MAILMAN_USED_LANGUAGES="fr en"
ALTERNC_MAILMAN_CREATE_SITE_LIST=""
ALTERNC_MAILMAN_PATCH_MAILMAN="true"
ALTERNC_PHPMYADMIN_ADMINUSER="root"
ALTERNC_PHPMYADMIN_DBCONFIG="false"
ALTERNC_PHPMYADMIN_USERNAME="admin"
ALTERNC_PHPMYADMIN_USERPASSWORD="" # Set during install
ALTERNC_PHPMYADMIN_WEBSERVER="apache2"
ALTERNC_POSTFIX_MAILERTYPE="Internet Site"
ALTERNC_PROFTPD_STANDALONE="standalone"


ADDITIONAL_PACKAGES=""
VAR_SKIP=0
VAR_TEST_IP=91.194.60.1
VAR_HAS_NET=0


# Output & Translations utilities 
# @see http://mywiki.wooledge.org/BashFAQ/098
# @see http://www.linuxtopia.org/online_books/advanced_bash_scripting_guide/localization.html
export TEXTDOMAIN=alternc-easy-install
export TEXTDOMAINDIR=$(pwd)/translations

debug() {

    echo -e $COL_PURPLE;
    local format="$1"
    shift
    printf "$(gettext -d $TEXTDOMAIN -s "$format")" "$@" # >&1
    echo -e $COL_RESET;
}

misc() {
    
    echo -e $COL_GRAY;
    local format="$1"
    shift
    printf "$(gettext -d $TEXTDOMAIN -s "$format")" "$@" # >&1
    echo -e $COL_RESET;

}
ask() {
    echo -e $COL_WHITE;
    local format="$1"
    shift
    printf "$(gettext -d $TEXTDOMAIN -s "$format")" "$@" # >&1
    echo -e $COL_RESET;

}

info() {
    
    echo -e $COL_GREEN;
    local format="$1"
    shift
    printf "$(gettext -d $TEXTDOMAIN -s "$format")" "$@"
    echo -e $COL_RESET;

}

warn() {

    echo -e $COL_RED;
    local format="$1"
    shift
    printf "$(gettext -d $TEXTDOMAIN -s "$format")" "$@" 
    echo -e $COL_RESET;

}

alert() {

    echo -e $COL_RED;
    local format="$1"
    shift
    printf "\n"
    printf "$(gettext 'A critical error occured: ' )" 
    printf "$(gettext -d $TEXTDOMAIN -s "$format")" "$@" 
    printf "\n"
    printf "$(gettext 'Exiting.'  )" 
    printf "\n"
    echo -e $COL_RESET;
    exit $E_CDERROR

}


spacer() {
    
    echo -e $COL_GRAY;
    echo -e " - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    echo -e $COL_RESET;

}

### Various utilities

## Exit
try_exit() {
    if [[ "$SILENT" == 1 ]] ;
        then return 1
    fi;

    if [ -z $1 ] ; then
        ask "Do you want to continue the installation? (Y/n)"
    else
        ask $1;
    fi;
    read VAR_SKIP;
    if [[ "n" == ${VAR_SKIP,,} ]] ; 
        then warn "Exiting";
        exit 1;
    fi;
}

## wraps apt-get
apt_get() {
    package_list="$@"
    local cmd="apt-get install -y $package_list"
    if [[ $DRY_RUN = 1 ]] ; then
        debug "System should execute %s $package_list"
    else
        if [[ $DEBUG = 1 ]] ; then 
            debug "$cmd"
        fi;    
        $cmd || alert "Failed to following package(s): [ $package_list ]"
    fi;
}


# Testing utilities

test_ns() {
    local NS=$1
    if [[ -z "$NS" ]] ; then
        warn "missing domain name"
        return 1
    fi;
    local cmd="$(dig +short A $NS)"
    if [[ $cmd = "" ]] ; then
        alert "%s is not a valid domain name" "$NS"
    else 
        info "%s is a valid domain name" "$NS"
    fi;
}

test_local_ip() {
    local IP="$1"
    local VALID=0
    for ip in  $(ip addr show | grep inet | cut -d' ' -f6 | cut -d/ -f1|tr '\n' ' '  ) ; do
        if [[ "$IP" = "$ip" ]]; then
            VALID=1
        fi;
    done;
    if [ $VALID = 0 ] ; then 
        alert "%s doesn't seem to be a valid local ip" "$IP"
    fi;
}


# Sets a debconf variable
# @param 1 var
# @param 2 type
# @param 3 value
# @param 4 database default=alternc
debconf() {
    local database;
    if [ -z $4 ] ; then
        database="alternc"
    else 
        database="$4"    
    fi;
    if [[ $DRY_RUN == 1 ]] ; then
        debug "System sets debconf $database %s %s %s" "$1" "$2" "$3"
    else
        if [[ $DEBUG == 1 ]] ; then 
            debug "[OK] debconf $database %s %s %s" "$1" "$2" "$3"
        fi;    
        # sets the selection
        echo "$database $1 $2 $3" | debconf-set-selections
        # marks the selection as read
        echo "$database $1 seen true" | debconf-set-selections
    fi;
}


# gateway for all 'y,o' user inputs management
validate() {
    local VAR=$1
    if [[ "n" == ${VAR,,} ]] ; then
        echo 0;
        return 0;
    fi;
    echo 1;
    return 1;
}

# @todo : request a subdomain
alternc_net_get_domain(){
    echo "todo"
}

# Encapsulates cp 
# @param 1 source file
# @param 2 target file 
copy(){
    if [[ $DRY_RUN = 1 ]] ; then
        debug "System copies %s as %s" "$1" "$2" 
    else
        if [[ $DEBUG = 1 ]] ; then 
            debug "cp %s %s" "$1" "$2" 
        fi;    
        ensure_file_exists "$1"  
        ensure_file_path_exists "$2"
        cp "$1" "$2"
    fi;
}

# Makes sure a necessary file exists, or exits  
# @param 1 a file path
ensure_file_exists(){
    if [[ $DRY_RUN = 1 ]] ; then
        debug "System makes sure file %s  exists" "$1"
    else
        if [[ $DEBUG = 1 ]] ; then 
            debug "Checking file %s exists" "$1"
        fi;    
        if [[ ! -f "$1" ]] ; then
            alert "File %s does not exist" "$1"
        fi;
    fi;
}

# Creates folders path for file if necessary  
# @param 1 a file path
ensure_file_path_exists(){
    if [[ $DRY_RUN = 1 ]] ; then
        debug "System makes sure path for %s  exists" "$1"
    else
        local dir_path=$(echo "$1" | sed -e "s/\(.*\)\/.*/\1/")
        if [[ -d "$dir_path" ]] ; then 
            return 1
        fi
        if [[ -f "$dir_path" ]] ; then 
            warn "Failed to create %s as it is a file already" "$dir_path"
            return 0
        fi
        if [[ $DEBUG = 1 ]] ; then 
            debug "Creating folder %s for file %s" "$dir_path" "$1"
        fi;    
        mkdir -p "$dir_path"
    fi;
}

# Encapsulates rm 
# @param 1 file
delete(){
    if [[ $DRY_RUN = 1 ]] ; then
        debug "System deletes %s" "$1"
        return 1
    fi
    # If no file, exit
    if [ ! -f "$1" ] ; then
        return 1
    fi
    if [[ $DEBUG = 1 ]] ; then 
        debug "Deleting %s" "$1"
    fi;    
    rm -f $1
    return 1
}

# Encapsulates echo $1 > $2
# @param 1 content
# @param 2 file
write() {
    
    if [[ $DRY_RUN == 1 ]] ; then
        debug "System writes '%s' \nin %s" "$1" "$2"
    else
        if [[ $DEBUG == 1 ]] ; then 
            debug "Writing '%s' \nin %s" "$1" "$2"
        fi;    
        # backups file if exists
        backup_file "$2"
        # touch file
        rm -f "$2"
        touch "$2"
        # echo each text line
        # in a subshell to not mess IFS
        $(IFS="
";for line in $(echo "$1"); do echo $line >> $2; done;)
    fi;
    
}

# inserts a line in file at line number
# @param 1 file path
# @param 2 line #
# @param 3 line
insert(){
    if [[ $DRY_RUN == 1 ]] ; then
        debug "Systems inserts '%s' in %s at line #%s" "$3" "$1" "$2" 
        return 1
    fi;
    sed -i "$2 i\
$3"     $1
    return 1
    
}

# replaces string $1 in by $2 in $3
# @param 1 regexp
# @param 2 replacement
# @param 3 file path
replace(){
    if [[ $DRY_RUN == 1 ]] ; then
        debug "Systems replaces '%s' by %s in %s" "$1" "$2" "$3"
        return 1
    fi;
    if [[ $DEBUG == 1 ]] ; then 
        debug "Replacing '%s' by %s in %s" "$1" "$2" "$3"
    fi;
    sed -i -e "s/$1/$2/" "$3"
    return 1
    
}

# backups file if exists
# @param 1 file path
backup_file(){
    if [[ $DRY_RUN == 1 ]] ; then
        debug "Systems makes a backup of %s" "$1"
        return 1
    fi;
    if [ -f "$1" ] ; then
        local backed=0
        local num=1
        while [[ $backed != 1 ]] ; do 
            if [ -f "$1.$num" ] ; then
                num=$(( $num + 1 ))
            else
                cp "$1" "$1.$num"
                touch "$1"
                backed=1
            fi;
        done;
        if [[ $DEBUG == 1 ]] ; then 
            debug "File %s backed as %s.$num" "$1" "$1"
        fi;
        return 1
    fi;
    return 0
}

# Attempts to check if a service is currently running 
# @param 1     the service name ex: mysqld
#            This must be an /etc/init.d script name
check_service() {
    if [ -z $1 ] ; then
        alert "Missing service name %s" "$1"
    fi;
    local service=$1
    if [ $(pgrep $1 | wc -l) -eq 0 ] ; then
        warn "Service $service is not running"
    else
        info "Service $service is running OK"
    fi;    
}


# Edits the fstab file to add quota and acl tags to partition mounting
# @param 1    (optional) file name, default = /etc/fstab
fstab_quota_and_acl(){

    if [[ $DRY_RUN == 1 ]] ; then 
        debug "System edits the fstab to activate acl and quota "
    fi;
    local line_num=1;
    # Stores the old Internal Field Separator
    OLD_IFS=$IFS
    # Sets the IFS to new line
    IFS="
    "
    # Sets the edited file (allows testing)
    local file=""
    # Default file
    if [ -z "$1" ] ; then
        file="/etc/fstab"
    # Custom file
    else 
        file="$1"
        if [ ! -f "$1" ] ; then 
            warn "%s is not a valid file" "$1"
        fi
    fi;
    # Runs through each line of the fstab file
    for line in $(cat "$file"); do
        # Identifies mount point if not a comment
        mount_point=$( echo "$line"|grep -v "^#"|awk '{print $2}');
        # Edits the identified line for / system 
        if [[ "$mount_point" == "/" ]] ; then 
            # The / line with a comment
            commented_line="# $line"
            # The / line with acl and quota
            edited_line=$(echo $line|awk '{print $1"\t"$2"\t"$3"\tacl,quota,"$4"\t"$5"\t"$6}')
            # The n+1 line number 
            new_line_num=$((line_num + 1))
            # Actual sed operation
sed -i -e "${line_num}d" -e "${new_line_num}i\
# The next line was commented to add quota and acl on the root file system" -e "${new_line_num}i\
$commented_line" -e "${new_line_num}i\
$edited_line" $file
        fi; 
        # Not found, keep searching
        line_num=$(( $line_num + 1 ));
    done
    # Resets the IFS
    IFS=$OLD_IFS
}

