#!/bin/sh

set -e

if [ -z "${ROOT_DN}" ]; then
    ROOT_DN="cn=ldapadmin,${BASE_DN:?not set}"
fi

# Logging
# -1	enable all debugging
# 0	no debugging
# 1	trace function calls
# 2	debug packet handling
# 4	heavy trace debugging
# 8	connection management
# 16	print out packets sent and received
# 32	search filter processing
# 64	configuration file processing
# 128	access control list processing
# 256	stats log connections/operations/results
# 512	stats log entries sent
# 1024	print communication with shell backends
# 2048	print entry parsing debugging

if [ -z "${DEBUG}" ]; then
    DEBUG=$(( 32+64+128 ))
fi

mkdir -p /run/ldap /etc/ldap /var/lib/ldap/data

chown -R ldap.ldap /run/ldap /var/lib/ldap

cat << EOF > /etc/ldap/slapd.conf
pidfile /run/ldap/slapd.pid
argsfile /run/ldap/slapd.args

include /etc/openldap/schema/core.schema
include /etc/openldap/schema/misc.schema
include /etc/openldap/schema/cosine.schema
include /etc/openldap/schema/nis.schema
include /etc/openldap/schema/inetorgperson.schema
include /etc/openldap/custom-schema/samba.schema
include /etc/openldap/custom-schema/microsoftattributetype.schema
include /etc/openldap/custom-schema/microsoftattributetypestd.schema
include /etc/openldap/custom-schema/microsoftobjectclass.schema


modulepath	/usr/lib/openldap
moduleload	back_mdb

database  ${LDAP_BACKEND:-ldif}
directory /var/lib/ldap/data

suffix		"${BASE_DN}"
rootdn		"${ROOT_DN}"
rootpw      "${ROOT_DN_PASSWORD:?not set}"

# allow users to change their password
access to attrs=userPassword
        by self write
        by anonymous auth
        by users none

access to *
        by users read
        by * none

#####################################################################
###
### memberof overlay config
###
moduleload	memberof
overlay memberof

memberof-group-oc groupOfUniqueNames
memberof-member-ad uniqueMember
memberof-memberof-ad memberOf
memberof-dangling error

# maintain referential integrity
memberof-refint true


#####################################################################
###
### refint overlay config
###
moduleload	refint
overlay refint

refint_attributes member memberOf

EOF

LISTEN_SCHEMA="ldap:///"

if [ ! -z "${SSL_CA_FILE}" -o ! -z "${SSL_CERT_FILE}" -o  ! -z "${SSL_KEY_FILE}" ]; then

    if [ ! -e "${SSL_CA_FILE:?not set}" ]; then
      echo "Missing SSL_CA_FILE: ${SSL_CA_FILE}"
      exit 1
    fi

    if [ ! -e "${SSL_CERT_FILE:?not set}" ]; then
      echo "Missing SSL_CERT_FILE: ${SSL_CERT_FILE}"
      exit 1
    fi

    if [ ! -e "${SSL_KEY_FILE:?not set}" ]; then
      echo "Missing SSL_KEY_FILE: ${SSL_KEY_FILE}"
      exit 1
    fi

    cat << EOF >> /etc/ldap/slapd.conf

# enable SSL
TLSCipherSuite HIGH:MEDIUM:-SSLv2:-SSLv3
TLSCACertificateFile ${SSL_CA_FILE}
TLSCertificateFile ${SSL_CERT_FILE}
TLSCertificateKeyFile ${SSL_KEY_FILE}
EOF

# commented out by tgruenert 
# blocks internal unencrypted traffic
#     if [ "${LDAP_ENFORCE_TLS:-true}"!="false" ]; then
#         cat << EOF >> /etc/ldap/slapd.conf
# # enfore tls on plain socket
# security tls=1
# EOF
#     fi

    LISTEN_SCHEMA="${LISTEN_SCHEMA} ldaps:///"
fi

exec /usr/sbin/slapd -u ldap -g ldap -d ${DEBUG} -h "${LISTEN_SCHEMA}" -f /etc/ldap/slapd.conf
