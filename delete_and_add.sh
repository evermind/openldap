#!/bin/sh

if [ -z "$1" ]; then
  echo "USAGE: $0 file.ldiff"
  exit 1
fi

# Don't verify ssl certs
export LDAPTLS_REQCERT=never

# delete (reverse order)
tac $1 | grep -e "^dn: " | awk '{print $2 }' | ldapdelete -Z -c -x -D "cn=ldapadmin,dc=evermind,dc=de" -w secret

# add
cat $1 | ldapadd -Z -c -x -D "cn=ldapadmin,dc=evermind,dc=de" -w secret


ldapsearch -Z -D "cn=ldapadmin,dc=evermind,dc=de" -w secret -x -b "dc=evermind,dc=de" "(&(objectclass=inetOrgPerson)(memberOf=cn=admins,ou=groups,dc=evermind,dc=de))"
