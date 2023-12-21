FROM docker.io/alpine:3.19

RUN apk add --no-cache openconnect dnsmasq ca-certificates xmlstarlet curl

WORKDIR /vpn
COPY ./entrypoint.sh .

HEALTHCHECK --start-period=15s --retries=1 \
  CMD pgrep openconnect || exit 1; pgrep dnsmasq || exit 1

ENTRYPOINT ["/vpn/entrypoint.sh"]
