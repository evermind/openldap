FROM alpine:3.11

RUN apk add --update --no-cache --purge --clean-protected \
      openldap openldap-clients pwgen \
      openldap-back-mdb \
      openldap-overlay-memberof \
      openldap-overlay-refint

#ADD schema/*.schema /etc/openldap/schema/

ADD start.sh /start.sh

EXPOSE 389

CMD ["/start.sh"]
