FROM debian:bookworm-slim

LABEL maintainer="@zorbax"

ENV PG_MAJOR=14 \
    PG_VERSION=14.11-1.pgdg120+2 \
    DEBIAN_FRONTEND=noninteractive

RUN apt-get update -qq \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        gnupg \
        less \
        libnss-wrapper \
        locales \
        wget \
        xz-utils \
        zstd \
        dpkg-dev

# explicitly set user/group IDs
RUN groupadd -r postgres --gid=999 \
    && useradd -r -g postgres --uid=999 --home-dir=/var/lib/postgresql --shell=/bin/bash postgres \
    && mkdir -p /var/lib/postgresql \
    && chown -R postgres:postgres /var/lib/postgresql \
    && mkdir /docker-entrypoint-initdb.d

ENV GOSU_VERSION 1.17
RUN savedAptMark="$(apt-mark showmanual)"; \
    GNUPGHOME="$(mktemp -d)"; \ 
    dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')" \
    && wget -O /usr/local/bin/gosu https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-${dpkgArch} \
    && wget -O /usr/local/bin/gosu.asc https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-${dpkgArch}.asc \
    && gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
    && gpgconf --kill all \
    && apt-mark auto '.*' > /dev/null \
    && [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark > /dev/null \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
    && rm -rf ${GNUPGHOME} /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu \
    && gosu nobody true 

RUN if [ -f /etc/dpkg/dpkg.cfg.d/docker ]; then \
        grep -q '/usr/share/locale' /etc/dpkg/dpkg.cfg.d/docker; \
        sed -ri '#/usr/share#locale#d' /etc/dpkg/dpkg.cfg.d/docker; \
        ! grep -q '/usr/share/locale' /etc/dpkg/dpkg.cfg.d/docker; \
    fi ; \
    echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen \
    && locale-gen

ENV LANG="en_US.UTF-8" \
    LANGUAGE="en_US.UTF-8" \
    LC_ALL="en_US.UTF-8"

# amd64 | arm64 | ppc64el | s390x
# dpkgArch="$(dpkg --print-architecture)"

# pub   4096R/ACCC4CF8 2011-10-13 [expires: 2019-07-02]
#       Key fingerprint = B97B 0AFC AA1A 47F0 44F2  44A0 7FCC 7D46 ACCC 4CF8
# uid

ENV PATH=$PATH:/usr/lib/postgresql/$PG_MAJOR/bin \
    PYTHONDONTWRITEBYTECODE=1 \
    PGDATA=/var/lib/postgresql/data

RUN KEY='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8'; \
    GNUPGHOME="$(mktemp -d)" \
    && mkdir -p /usr/local/share/keyrings/ \
    && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys ${KEY} \
    && gpg --batch --export --armor ${KEY} > /usr/local/share/keyrings/postgres.gpg.asc \
    && gpgconf --kill all \
    && rm -rf "$GNUPGHOME"

ARG GPGKEY="[ signed-by=/usr/local/share/keyrings/postgres.gpg.asc ]"
ARG REPO="http://apt.postgresql.org/pub/repos/apt/ bookworm-pgdg main"
ARG APTREPO="$GPGKEY $REPO ${PG_MAJOR}"
ARG POSGRESCONF="/usr/share/postgresql/postgresql.conf.sample"

RUN echo "deb $APTREPO" > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update -qq \
    && apt-get install -y --no-install-recommends postgresql-common \
    && sed -ri 's/#(create_main_cluster) .*$/\1 = false/' /etc/postgresql-common/createcluster.conf \
    && apt-get install -y --no-install-recommends "postgresql-$PG_MAJOR=$PG_VERSION" \
    && dpkg-divert --add --rename --divert ${POSGRESCONF}.dpkg \
        /usr/share/postgresql/${PG_MAJOR}/postgresql.conf.sample \
    && cp -v /usr/share/postgresql/postgresql.conf.sample.dpkg ${POSGRESCONF} \
    && ln -sv ../postgresql.conf.sample /usr/share/postgresql/${PG_MAJOR}/ \
    && sed -ri "s!^#?(listen_addresses)\s*=\s*\S+.*!\1 = '*'!" ${POSGRESCONF} \
    && grep -F "listen_addresses = '*'" ${POSGRESCONF} \
    && mkdir -p /var/run/postgresql ${PGDATA} \
    && chown -R postgres:postgres /var/run/postgresql ${PGDATA} \
    && chmod 3777 /var/run/postgresql \
    && chmod 1777 ${PGDATA} \
    && rm -rf /var/lib/apt/lists/* \
    && find /usr -name '*.pyc' -type f -exec bash -c 'for pyc; do dpkg -S "$pyc" &> /dev/null || rm -vf "$pyc"; done' -- '{}' + 

  
COPY docker-entrypoint.sh docker-ensure-initdb.sh /usr/local/bin/ 
RUN chmod +x /usr/local/bin/docker*.sh \
    && ln -sT docker-ensure-initdb.sh /usr/local/bin/docker-enforce-initdb.sh 

VOLUME /var/lib/postgresql/data
 
ENTRYPOINT ["docker-entrypoint.sh"]

STOPSIGNAL SIGINT

EXPOSE 5432

CMD ["postgres"]