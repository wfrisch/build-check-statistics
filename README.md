
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
$ BCS_CONFIG=/etc/build_check_statistics.conf BCS_DATA=/var/lib/build_check_statistics ./container.sh web
```

### Deployment with systemd and apache2

`systemd/bcs-podman.service` runs the web server, and
`systemd/bcs-podman-update.timer` runs the scraper daily at 02:00. Both use
`/var/lib/build_check_statistics` on the host for state.

```
# mkdir -p /var/lib/build_check_statistics
# cp systemd/bcs-podman*.{service,timer} /etc/systemd/system/
# systemctl daemon-reload
# systemctl enable --now bcs-podman.service bcs-podman-update.timer
```

The server publishes on `127.0.0.1:8080` only, which is what the reverse proxy
in `apache2/build_check_statistics.conf` already expects.
