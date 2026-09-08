
# SUSE::BuildCheckStatistics

  A [Mojolicious](http://mojolicious.org) application for collecting statistics
  about rpmlint failures in [Open Build Service](http://openbuildservice.org/)
  projects.

![Screenshot](https://raw.githubusercontent.com/openSUSE/build-check-statistics/master/screenshot.png)

## Installation

  All you need is a one-liner, it takes less than a minute.

    $ curl -L https://cpanmin.us | perl - -n git://github.com/openSUSE/build-check-statistics.git@master

  We recommend the use of a [Perlbrew](http://perlbrew.pl) environment.

## Setup

Just create a configuration file under `/etc/build_check_statistics.conf`.

```
{
  obs       => 'https://build.opensuse.org/public',
  projects  => ['SomeProject', 'AnotherProject'],
  sqlite    => 'sqlite:/var/lib/build_check_statistics/test.db',
  hypnotoad => {
    pid_file => '/var/lib/build_check_statistics/hypnotoad.pid'
  }
}
```

The application passes an explicit `file` option to the `Config` plugin, so the
`MOJO_CONFIG` environment variable has no effect. To use a different
configuration, replace `build_check_statistics.conf` in the application home
directory.

Update and deploy statistics. This can be repeated at any time to update the
data.
```
$ build_check_statistics update
$ build_check_statistics deploy
```

![Screenshot2](https://raw.githubusercontent.com/openSUSE/build-check-statistics/master/screenshot2.png)

Start the web server.
```
$ build_check_statistics daemon -m production
```

## Container

A `Dockerfile` based on `opensuse/leap:16.0` and a `container.sh` helper are
included, for use with podman.

```
$ ./container.sh          # build the image, then run the web server
$ ./container.sh update   # scrape OBS and publish the results, then exit
```

All persistent state is the SQLite database under
`/var/lib/build_check_statistics`. Mount that *directory* as a volume, not the
database file itself, because SQLite creates `-wal` and `-shm` siblings next to
it. `container.sh` mounts `./data` there by default; override with `BCS_DATA`.

The image ships a default configuration that points the database at that
directory. To change `projects` or `obs`, copy
`container/build_check_statistics.conf`, edit it, and point `BCS_CONFIG` at it.

```
$ BCS_CONFIG=~/.config/build_check_statistics.conf ./container.sh web
```

### Deployment with systemd and apache2

`systemd/bcs-podman.service` runs the web server, and
`systemd/bcs-podman-update.timer` runs the scraper daily at 02:00. They are
systemd *user* units, for rootless podman.

The configuration is read from `~/.config/build_check_statistics.conf`, which
is bind-mounted over the one baked into the image. It has to exist, otherwise
podman refuses to start the container. Note that the `sqlite` path in it is the
path *inside* the container.

```
$ cp container/build_check_statistics.conf ~/.config/build_check_statistics.conf
$ $EDITOR ~/.config/build_check_statistics.conf
$ cp systemd/bcs-podman*.{service,timer} ~/.config/systemd/user/
$ systemctl --user daemon-reload
$ systemctl --user enable --now bcs-podman.service bcs-podman-update.timer
```

`StateDirectory=` creates `~/.local/state/build_check_statistics` for the
database, so there is nothing to set up by hand.

To keep the units running while you are not logged in:

```
$ loginctl enable-linger $USER
```

The server publishes on `127.0.0.1:8080` only, which is what the reverse proxy
in `apache2/build_check_statistics.conf` already expects.

### Serving under a subdirectory

To reverse proxy the application under a path such as
`https://myserver/rpmlint/`, set `prefix` in the configuration.

```
{
  obs      => 'https://build.opensuse.org/public',
  projects => ['Virtualization'],
  sqlite   => 'sqlite:/var/lib/build_check_statistics/rpmlint.db',
  prefix   => '/rpmlint'
}
```

Every URL in the templates is generated with `url_for`, including the static
assets, so the prefix is applied to all of them. The routes themselves are
unchanged, because apache2 strips the prefix again.

```
ProxyPass        /rpmlint/ http://localhost:8080/ keepalive=On
ProxyPassReverse /rpmlint/ http://localhost:8080/
RequestHeader set X-Forwarded-Proto "https"
```

Note the trailing slashes: `ProxyPass /rpmlint/` with a target of
`http://localhost:8080/` is what removes the prefix from the request path.

Mojolicious only trusts `X-Forwarded-Proto` when it knows it is behind a proxy,
so set `MOJO_REVERSE_PROXY=1` as well (the systemd unit already does). Without
it, anything the application generates as an absolute URL would come out as
`http` on an `https` site.
