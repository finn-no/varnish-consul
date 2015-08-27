#!/bin/bash

set -e
#set the DEBUG env variable to turn on debugging
[[ -n "$DEBUG" ]] && set -x

# Required vars
VARNISH_KV=${VARNISH_KV:-varnish/template/default}
CONSUL_LOGLEVEL=${CONSUL_LOGLEVEL:-debug}
CONSUL_SSL_VERIFY=${CONSUL_SSL_VERIFY:-true}

export VARNISH_KV

# set up SSL
if [ "$(ls -A /usr/local/share/ca-certificates)" ]; then
  # normally we'd use update-ca-certificates, but something about running it in
  # Alpine is off, and the certs don't get added. Fortunately, we only need to
  # add ca-certificates to the global store and it's all plain text.
  cat /usr/local/share/ca-certificates/* >> /etc/ssl/certs/ca-certificates.crt
fi

function usage {
cat <<USAGE
  launch.sh             Start a consul-backed varnish instance

Configure using the following environment variables:

Nginx vars:
  VARNISH_KV             Consul K/V path to template contents
                         (default varnish/template/default)

  VARNISH_DEBUG          If set, run consul-template once and check generated varnish.conf
                         (default not set)

  VARNISH_AUTH_TYPE      Use a preconfigured template for Nginx basic authentication
                         Can be basic/auth/<not set>
                         (default not set)

  VARNISH_AUTH_BASIC_KV  Consul K/V path for varnish users
                         (default not set)

Consul vars:
  CONSUL_LOG_LEVEL       Set the consul-template log level
                         (default debug)

  CONSUL_CONNECT         URI for Consul agent
                         (default not set)

  CONSUL_SSL             Connect to Consul using SSL
                         (default not set)

  CONSUL_SSL_VERIFY      Verify Consul SSL connection
                         (default true)

  CONSUL_TOKEN           Consul API token
                         (default not set)
USAGE
}

function config_auth {
  case ${VARNISH_AUTH_TYPE} in
    basic)
      ln -s /defaults/config.d/varnish-auth.cfg /consul-template/config.d/varnish-auth.cfg
      ln -s /defaults/templates/varnish-basic.tmpl /consul-template/templates/varnish-auth.tmpl
    ;;
  esac

  # varnish fails if the file does not exist so create an empty one for now
  touch /etc/varnish/varnish-auth.conf
}

function launch_consul_template {
  vars=$*
  ctargs=

  if [ -n "${VARNISH_AUTH_TYPE}" ]; then
    config_auth
  fi

  [[ -n "${CONSUL_CONNECT}" ]] && ctargs="${ctargs} -consul ${CONSUL_CONNECT}"
  [[ -n "${CONSUL_SSL}" ]] && ctargs="${ctargs} -ssl"
  [[ -n "${CONSUL_SSL}" ]] && ctargs="${ctargs} -ssl-verify=${CONSUL_SSL_VERIFY}"
  [[ -n "${CONSUL_TOKEN}" ]] && ctargs="${ctargs} -token ${CONSUL_TOKEN}"

  # Create an empty varnish.tmpl so consul-template will start
  touch /consul-template/templates/varnish.tmpl

  if [[ -n "${VARNISH_DEBUG}" ]]; then
    echo "Running consul template -once..."
    consul-template -log-level "${CONSUL_LOGLEVEL}" \
           -template /consul-template/templates/varnish.tmpl.in:/consul-template/templates/varnish.tmpl \
           "${ctargs}" -once

    consul-template -log-level "${CONSUL_LOGLEVEL}" \
                       -config /consul-template/config.d \
                       "${ctargs}" -once "${vars}"
    /scripts/varnish-run.sh
  else
    echo "Starting consul template..."
    exec consul-template -log-level "${CONSUL_LOGLEVEL}" \
                       -config /consul-template/config.d \
                       "${ctargs}" "${vars}"
  fi
}

launch_consul_template "$@"
