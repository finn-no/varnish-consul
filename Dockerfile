FROM asteris/consul-template:latest

RUN apk-install bash ca-certificates varnish

RUN mkdir -p /tmp/varnish /defaults

ADD templates/ /consul-template/templates
ADD config.d/ /consul-template/config.d
ADD defaults/ /defaults
ADD scripts /scripts/

CMD ["/scripts/launch.sh"]
