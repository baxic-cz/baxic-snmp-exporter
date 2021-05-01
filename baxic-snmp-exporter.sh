#!/bin/bash

PROGNAME='baxic-snmp-exporter.sh'

CONFFILE="/opt/prometheus-apps/${PROGNAME%.sh}/${PROGNAME%.sh}.conf"

export PROGNAME CONFFILE


# read_config_file
#   read configuration file
read_config_file() {

  unset SNMP

  if [[ ! -f "$CONFFILE" || ! -r "$CONFFILE" ]]; then
    echo "$PROGNAME: configuration file '$CONFFILE' not found"
    exit 2
  fi

  . "$CONFFILE"

}

read_config_file


# get_metrics
#   get all metrics for the module and target specified in the HTTP GET header
get_metrics() {

  local httpget module target

  local snmpconf modconf metric oid value
  local metrics metrics_len

  read httpget

  module="$(echo "$httpget" | sed -rn 's#^.*[&?]module=([^ &]*)(&[^ ]*)?.*[[:blank:]]+HTTP.*$#\1#p')"
  target="$(echo "$httpget" | sed -rn 's#^.*[&?]target=([^ &]*)(&[^ ]*)?.*[[:blank:]]+HTTP.*$#\1#p')"

  [[ -z "$module" || -z "$target" ]] && continue

  metrics="$(for snmpconf in "${SNMP[@]}"; do

    modconf="$(echo "$snmpconf" | cut -d: -f1)"
    metric="$(echo "$snmpconf" | cut -d: -f2)"
    oid="$(echo "$snmpconf" | cut -d: -f3)"

    [[ "$modconf" != "$module" ]] && continue

    value="$(snmpwalk -v 1 -c public "$target" "$oid" | sed -rn 's#[^:]*:[[:blank:]]*"?([[:digit:].]*)"?[[:blank:]]*$#\1#p')"

    [[ -n "$value" ]] && echo "$metric" "$value"

  done)"

  metrics_len="$(echo "$metrics" | wc -c)"

  echo 'HTTP/1.1 200 OK'
  echo "Content-Length: $metrics_len"
  echo 'Content-Type: text/plain'
  echo "Date: $(date -R -u | sed -r 's#\+0000$#GMT#')"
  echo
  echo "$metrics"

  return 0

}


export -f get_metrics
export -f read_config_file


# periodically return metrics for the specified modules and targets when requested
ncat -k -l 9089 -c 'read_config_file && get_metrics'


# exit
exit 0

