#!/bin/bash

set -x

if [[ ! -s /etc/varnish/varnish.conf ]]; then
  exit 0
fi

/usr/sbin/varnish -s reload
if [[ $? -eq 0 ]]; then
  /bin/echo "Reloading varnish..."
  exit 0
fi

/bin/echo "Checking varnish.conf..."
/usr/sbin/varnish -t -c /etc/varnish/varnish.conf
if [[ $? -ne 0 ]]; then
  /bin/echo "varnish.conf check failed..."
  exit 1
fi

/bin/echo "Starting varnish..."
/usr/sbin/varnish -c /etc/varnish/varnish.conf
exit $?
