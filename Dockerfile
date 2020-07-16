FROM consul:1.8.0

RUN apk add openssl curl jq python py2-pip
RUN pip install s3cmd

ADD consul-backup.sh /root/consul-backup.sh
RUN chmod go+rx /root/consul-backup.sh

ENTRYPOINT ["/bin/sh", "/root/consul-backup.sh"]