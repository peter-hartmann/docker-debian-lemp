#!/bin/bash

declare -A CONFIG_PARAMS=(
    ["RELAY_HOST"]="[smtp.gmail.com]:587"
    ["RELAY_CRED"]="[smtp.gmail.com]:587 EMAILUSERNAME:EMAILPASSWORD"
);

declare -A CONFIG_FILE=(
    ["RELAY_CRED"]="/etc/postfix/sasl/sasl_passwd"
    ["RELAY_HOST"]="/etc/postfix/main.cf"
);

declare -A CONFIG_METHOD=(
    ["RELAY_CRED"]="substitude_next_line"
    ["RELAY_HOST"]="named_value"
);

declare -A CONFIG_PATTERN=(
    ["RELAY_CRED"]="#SMTP_RELAY_HOST"
    ["RELAY_HOST"]="relayhost *= *"
);

declare -A CONFIG_ACTION=(
    ["RELAY_CRED"]="init_postfix"
    ["RELAY_HOST"]="init_postfix"
);

function init_postfix() {
    postmap /etc/postfix/sasl/sasl_passwd
    rm /var/spool/postfix/pid/master.pid
    service postfix stop;
    service postfix start;
}

############################################################################################################

if ! [ -f /.dockerenv ]; then echo "Run this file in the container using:"$'\n'"  docker exec -it CONTAINERID /backup/${0##*/}"$'\n'; exit 1; fi

function Set () {
    local tmpfile=/tmp/last_config.txt;
    local tmpsed=/tmp/last_config_sed.txt;
    local filename=${CONFIG_FILE[$1]};
    local method=${CONFIG_METHOD[$1]};
    local pattern=${CONFIG_PATTERN[$1]};
    local value=$2;
    local action=${CONFIG_ACTION[$1]};
    case "$method" in
        substitude_next_line)
            sed '/'"$pattern"'/!b;n;s|.*|'"$value"'|w '"$tmpsed" "$filename" >$tmpfile;
            ;;
        named_value)
            sed -r 's|('"$pattern"').*|\1'"$value"'|w '"$tmpsed" "$filename" >$tmpfile
            ;;
        *)
            echo "Error: unknow substitution method."
            cat /dev/null > sed.txt;
            ;;
    esac
    cmp --silent $filename $tmpfile || {
        echo ""
        echo "###### Updateding: $filename"
        diff $filename $tmpfile
        cp $tmpfile $filename
        ACTIONS[$action]=true;
    }
}

declare -A ACTIONS;

if [ ${#CONFIG_PARAMS[@]} -ne 0 ]; then 
    echo "###### Comparing config params";
    for i in "${!CONFIG_PARAMS[@]}"; do
        Set $i "${CONFIG_PARAMS[$i]}"
    done
fi

if [ ${#ACTIONS[@]} -ne 0 ]; then 
    echo "###### Running actions";
    for i in "${!ACTIONS[@]}"; do
        if [ ${ACTIONS[$i]} ]; then
            echo "#### Action: $i";
            $i;
        fi
    done
fi
echo "###### Done"