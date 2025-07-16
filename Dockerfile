FROM docker.io/alpine:3.22.1

RUN apk add --no-cache \
  bash \
  ca-certificates \
  curl \
  dnsmasq \
  openconnect \
  xmlstarlet

WORKDIR /vpn
COPY ./entrypoint.sh .

HEALTHCHECK --start-period=15s --retries=1 \
  CMD pgrep openconnect || exit 1; pgrep dnsmasq || exit 1

ENTRYPOINT ["/vpn/entrypoint.sh"]
