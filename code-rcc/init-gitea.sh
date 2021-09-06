#!/bin/sh
set -e

GITEA="/usr/local/bin/gitea -c /etc/gitea/app.ini"

echo "[*] Gitea command: \$GITEA = $GITEA"

if [ -z "$GITEA_ADMIN_USER" ]; then
    echo "[!] \$GITEA_ADMIN_USER not set"
    exit 2
fi
echo "[*] Admin user:     $GITEA_ADMIN_USER"

if [ -z "$GITEA_ADMIN_PASSWORD" ]; then
    echo "[!] \$GITEA_ADMIN_PASSWORD not set"
    exit 2
fi
echo "[*] Admin password: hunter2"

if [ -z "$GITEA_ADMIN_EMAIL" ]; then
    echo "[!] \$GITEA_ADMIN_EMAIL not set"
    exit 2
fi
echo "[*] Admin email:    $GITEA_ADMIN_EMAIL"

if [ -z "$GITEA_LDAP_HOST" ]; then
    echo "[!] \$GITEA_LDAP_HOST not set"
    exit 2
fi
echo "[*] LDAP Host:      $GITEA_LDAP_HOST"

if [ -z "$GITEA_LDAP_USER" ]; then
    echo "[!] \$GITEA_LDAP_USER not set"
    exit 2
fi
echo "[*] LDAP Bind User: $GITEA_LDAP_USER"

if [ -z "$GITEA_LDAP_PASSWORD" ]; then
    echo "[!] \$GITEA_LDAP_PASSWORD not set"
    exit 2
fi
echo "[*] LDAP Bind Password: hunter3"

if [ -z "$GITEA_UQSTAFF_SEARCH_BASE" ]; then
    echo "[!] \$GITEA_UQSTAFF_SEARCH_BASE not set"
    exit 2
fi

if [ -z "$GITEA_UQSTAFF_FILTER" ]; then
    echo "[!] \$GITEA_UQSTAFF_FILTER not set"
    exit 2
fi

if [ -z "$GITEA_UQNONSTAFF_SEARCH_BASE" ]; then
    echo "[!] \$GITEA_UQNONSTAFF_SEARCH_BASE not set"
    exit 2
fi

if [ -z "$GITEA_UQNONSTAFF_FILTER" ]; then
    echo "[!] \$GITEA_UQNONSTAFF_FILTER not set"
    exit 2
fi

echo "[*] Home directory: $HOME"
mkdir -p "$HOME"
chown -R 1000:1000 "$HOME"

# Init/migrate the database so we don't need to run setup manually
echo "[*] Running migration"
$GITEA migrate


echo "[*] Dumping admin users"
$GITEA admin user list --admin

# Create the admin user if it doesn't exist
if [ -z "$($GITEA admin user list --admin | grep -e '^\d\+\s\+' | awk '{ print $2 }' | grep -- "$GITEA_ADMIN_USER")" ]; then
    echo "[*] User doesn't exist, creating"
    $GITEA admin user create --admin \
        --username "$GITEA_ADMIN_USER" \
        --password "$GITEA_ADMIN_PASSWORD" \
        --email "$GITEA_ADMIN_EMAIL"
else
    echo "[*] User exists, resetting password"
    $GITEA admin user change-password --username "$GITEA_ADMIN_USER" --password "$GITEA_ADMIN_PASSWORD"
fi

echo "[*] Dumping authentication sources"

##
# Add LDAP sources. We create two:
# uq-staff-rcc    - for staff in the RCC OU
# uq-staff-nonrcc - for staff not in the RCC OU
# This is dodgy and the AD should be fixed.
##
ldap_id=$($GITEA admin auth list | grep -e '^\d\+\s\+uq-staff-rcc' | awk '{ print $1 }')
if [ -z "$ldap_id" ]; then
    echo "[*] uq-staff-rcc authentication source doesn't exist, creating"
    ldap_cmd="add-ldap"
else
    echo "[*] uq-staff-rcc authentication exists, updating"
    ldap_cmd="update-ldap --id=$ldap_id"
fi

$GITEA admin auth $ldap_cmd \
    --name uq-staff-rcc \
    --host "$GITEA_LDAP_HOST" \
    --port 636 \
    --security-protocol ldaps \
    --bind-dn "$GITEA_LDAP_USER" \
    --bind-password "$GITEA_LDAP_PASSWORD" \
    --synchronize-users \
    --username-attribute sAMAccountName \
    --firstname-attribute givenName \
    --surname-attribute sn \
    --email-attribute mail \
    --user-search-base "$GITEA_UQSTAFF_SEARCH_BASE" \
    --user-filter "$GITEA_UQSTAFF_FILTER"

ldap_id=$($GITEA admin auth list | grep -e '^\d\+\s\+uq-staff-nonrcc' | awk '{ print $1 }')
if [ -z "$ldap_id" ]; then
    echo "[*] uq-staff-nonrcc authentication source doesn't exist, creating"
    ldap_cmd="add-ldap"
else
    echo "[*] uq-staff-nonrcc authentication exists, updating"
    ldap_cmd="update-ldap --id=$ldap_id"
fi

$GITEA admin auth $ldap_cmd \
    --name uq-staff-nonrcc \
    --host "$GITEA_LDAP_HOST" \
    --port 636 \
    --security-protocol ldaps \
    --bind-dn "$GITEA_LDAP_USER" \
    --bind-password "$GITEA_LDAP_PASSWORD" \
    --synchronize-users \
    --username-attribute sAMAccountName \
    --firstname-attribute givenName \
    --surname-attribute sn \
    --email-attribute mail \
    --user-search-base "$GITEA_UQNONSTAFF_SEARCH_BASE" \
    --user-filter "$GITEA_UQNONSTAFF_FILTER"
