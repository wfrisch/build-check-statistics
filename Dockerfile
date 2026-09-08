FROM opensuse/leap:16.0

RUN zypper -n --gpg-auto-import-keys refresh \
 && zypper -n install --no-recommends \
      perl-Mojolicious \
      perl-Mojo-SQLite \
      perl-Term-ProgressBar \
      perl-DBD-SQLite \
      perl-IO-Socket-SSL \
 && zypper clean -a

WORKDIR /app
COPY lib/ lib/
COPY migrations/ migrations/
COPY public/ public/
COPY script/ script/
COPY templates/ templates/
COPY container/build_check_statistics.conf ./build_check_statistics.conf

# All persistent state lives here: the SQLite database plus its -wal/-shm
# siblings. Mount this directory as a volume.
RUN mkdir -p /var/lib/build_check_statistics

EXPOSE 8080
ENTRYPOINT ["/app/script/build_check_statistics"]
CMD ["prefork", "-w", "4", "-m", "production", "-l", "http://*:8080"]
