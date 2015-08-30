#!/bin/bash

set -x
default_vcl=/etc/varnish/default.vcl
secret_file=/etc/varnish/secret

if [[ ! -f "$default_vcl" ]]; then
  /bin/echo "No vcl found at $default_vcl, cannot start varnish"
  exit 1
fi

if [[ ! -f "$secret_file" ]]; then
  dd if=/dev/random of="$secret_file" count=1
fi

if ! pgrep "varnishd" > /dev/null; then
  /usr/sbin/varnishd -f "$default_vcl" -S "$secret_file"
  if [[ $? -eq 0 ]]; then
    /bin/echo "Started varnish"
    exit 0
  fi
else
  timestamp=$(date +%s)
  varnishadm -S /etc/varnish/secret vcl.load "default_vcl_$timestamp" "$default_vcl"
  varnishadm -S /etc/varnish/secret vcl.use "default_vcl_$timestamp"
  if [[ $? -eq 0 ]]; then
    /bin/echo "Reloaded varnish"
    exit 0
  fi
fi
