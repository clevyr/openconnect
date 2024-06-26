#!/bin/sh
#
# Alex Wicks, 2021
# github.com/aw1cks
#

get_resolv_nameservers() {
  grep '^nameserver' /etc/resolv.conf | awk '{print $2}'
}

printf "\e[32m
    ___      ___      ___       __      ___      ___       __       __      ___      ___    __  ___ 
  //   ) ) //   ) ) //___) ) //   ) ) //   ) ) //   ) ) //   ) ) //   ) ) //___) ) //   ) )  / /    
 //   / / //___/ / //       //   / / //       //   / / //   / / //   / / //       //        / /     
((___/ / //       ((____   //   / / ((____   ((___/ / //   / / //   / / ((____   ((____    / /      
\e[0m\n"

# Test for presence of required vars
if [ -z "${URL}" ]
then
  printf "\e[31m\$URL is not set\n\e[0m" 
  exit 1
fi
printf "\e[33mURL:\e[0m %s \n" "${URL}"

if [ -z "${USER}" ]
then
  printf "\e[31m\$USER is not set\e[0m\n"
  exit 2
fi
printf "\e[33mUsername:\e[0m %s\n" "${USER}"

if [ -z "${PASS}" ]
then
  printf "\e[31m\$PASS is not set\e[0m\n"
  exit 3
fi
printf "\e[33mPassword:\e[0m [REDACTED]\n\n"

printf "\e[32mSetting mandatory arguments...\e[0m\n"
# Set user
OPENCONNECT_ARGS="--background --user=${USER} -i tun127 --passwd-on-stdin --non-inter"

# Test for auth group
printf "\e[32mChecking for authentication group parameter...\e[0m\n"
if [ -n "${AUTH_GROUP}" ]
then
  OPENCONNECT_ARGS="${OPENCONNECT_ARGS} --authgroup=${AUTH_GROUP}"
fi

# Add any additional arguments
printf "\e[32mChecking for additional arguments...\e[0m\n"
if [ -n "${EXTRA_ARGS}" ]
then
  OPENCONNECT_ARGS="${OPENCONNECT_ARGS} ${EXTRA_ARGS}"
fi

OPENCONNECT_ARGS="${OPENCONNECT_ARGS} --useragent=${USERAGENT:-AnyConnect}"

# URL needs to be the last argument
printf "\e[32mSetting URL...\e[0m\n"
OPENCONNECT_ARGS="${OPENCONNECT_ARGS} ${URL}"

printf "\e[32mStarting OpenConnect VPN...\e[0m\n"
printf "\e[33mArguments:\e[0m %s\n\n" "${OPENCONNECT_ARGS}"
# shellcheck disable=SC2086
(echo "${PASS}"; [ -n "${OTP}" ] && echo "${OTP}") | openconnect ${OPENCONNECT_ARGS}

# Add our initial dnsmasq config
printf '# Static options
no-resolv
strict-order

# Dynamically populated upstream servers\n' > /etc/dnsmasq.d/dns.conf

# Get the pre-VPN state from resolv.conf
OLD_RESOLV=$(get_resolv_nameservers)

# Sleep until the VPN comes up
# Otherwise the VPNC script won't populate resolv.conf
while ! grep -q VPNC /etc/resolv.conf
do
  sleep 5
done

# Add our dNAT now - since we know the VPN is up due to above
iptables -t nat -A POSTROUTING -o tun127 -j MASQUERADE

# Get our DNS Servers again, now that the VPNC script updated them
# Then populate the servers in dnsmasq config
NEW_RESOLV=$(get_resolv_nameservers)

for LOCAL_DOMAIN_SRV in ${OLD_RESOLV}
do
  printf "server=%s\n" "${LOCAL_DOMAIN_SRV}" >> /etc/dnsmasq.d/dns.conf
done

# Add any extra search domains, if specified
# Append them, after existing search domains, so that the host resolv.conf takes precedence
if [ -n "${SEARCH_DOMAINS}" ]
then
  # Docker bind mounts resolv.conf at runtime
  # This weirdness bypasses an error that looks as such:
  # sed: can't move '/etc/resolv.confahaCgd' to '/etc/resolv.conf': Resource busy
  # shellcheck disable=SC2005
  echo "$(sed "/search/ s/$/ ${SEARCH_DOMAINS}/" /etc/resolv.conf)" > /etc/resolv.conf
  # Add search domains as forwarders.
  # This prevents DNS leaks, since only these domains will be resolved via VPN-configured DNS servers.
  printf '
  # DNS forwarders\n' >> /etc/dnsmasq.d/dns.conf
  for REMOTE_DOMAIN_SRV in ${NEW_RESOLV}
  do
    for DOMAIN in ${SEARCH_DOMAINS}
    do
      printf "server=/%s/%s\n" "${DOMAIN}" "${REMOTE_DOMAIN_SRV}" >> /etc/dnsmasq.d/dns.conf
    done
  done
fi

printf "\n\e[32mStarting dnsmasq...\e[0m\n"
dnsmasq -k --log-facility=- -C /etc/dnsmasq.d/dns.conf
