# OpenConnect Docker Container

[![Build](https://github.com/clevyr/openconnect/actions/workflows/main.yml/badge.svg)](https://github.com/clevyr/openconnect/actions/workflows/main.yml)

## Why?

OpenConnect doesn't ship with any init scripts or systemd units.
It's also not easy to non-interactively provide username, password and especially OTP.
Additionally, running in a docker container gives some extra flexibility with routing.

## Where can I download it?

The image is built by GitHub Actions for amd64 & arm64 and pushed to the following repositories:

 - [GitHub Container Registry](https://github.com/orgs/clevyr/packages/container/package/openconnect)

## How do I use it?

It's recommended to use the helper scripts [as described below](#helper-scripts).

Otherwise, you can run the container using the specified arguments below.

### Basic container command

```shell
docker run -d \
--cap-add NET_ADMIN \
-e URL=https://my.vpn.com \
-e USER=myuser \
-e AUTH_GROUP=mygroup \
-e PASS=mypassword \
-e OTP=123456 \
-e SEARCH_DOMAINS="my.corporate-domain.com subdomain.my.corporate-domain.com" \
docker.io/aw1cks/openconnect'
```

### All container arguments

| Variable         | Explanation                                                                                                                                  | Example Value                                               |
|------------------|----------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------|
| `URL`            | URL of AnyConnect VPN                                                                                                                        | `https://my.vpn.com`                                        |
| `USER`           | User to authenticate with                                                                                                                    | `myuser`                                                    |
| `AUTH_GROUP`     | Authentication Group to use when connecting to VPN (optional)                                                                                | `mygroup`                                                   |
| `PASS`           | Password to authenticate with                                                                                                                | `mypassword`                                                |
| `OTP`            | OTP/2FA code (optional)                                                                                                                      | `123456`                                                    |
| `SEARCH_DOMAINS` | Search domains to use. DNS for these domains will be routed via the VPN's DNS servers (optional). Separate with a space for multiple domains | `my.corporate-domain.com subdomain.my.corporate-domain.com` |
| `USERAGENT`      | User-Agent to pass to OpenConnect.                                                                                                           | `AnyConnect`                                                |
| `EXTRA_ARGS`     | Any additional arguments to be passed to the OpenConnect client (optional). Only use this if you need something specific                     | `--verbose`                                                 |

## Helper scripts

The provided helper scripts in `examples/` will create the container for you and set up the routing table appropriately.

### Requirements
 - `docker`
 - `sudo` (and permissions to run `ip` and `docker` as root)
 - `iproute2`
 - `jq`

### How do they work?

1. The `env` file is sourced from the same directory the script lives in
2. From the above file, all the container arguments are derived. These are passed using `-e` as environment variables to the container.
3. The container is spawned, then the address of the container is found using `docker inspect` piped to `jq`.
4. The routes specified in the `env` file are added to the **host** routing table, via the container address discovered in the previous step.
5. The host resolv.conf is backed up to `/etc/resolv.conf.orig`, then modified to point to the local container on `127.0.0.1`.

The script which stops the VPN cleans up the routing table, tears down the container, and restores the original `resolv.conf`.

### How do I use them?

```shell
$ cd $(git rev-parse --show-cdup)
$ cp examples/* .
$ $EDITOR env # set your values here
$ ./run.sh
$ ./stop.sh # Tears down the container and cleans up the routing table
```

## Building the container yourself

```shell
docker build -t openconnect .
```

## Known issues

When running not in privileged mode, OpenConnect gives errors such as this:

`Cannot open "/proc/sys/net/ipv4/route/flush"`

This is normal and does not impact the operation of the VPN.

To suppress these errors, run with `--privileged`.

