ARG DEBIAN_VERSION=bookworm
FROM debian:${DEBIAN_VERSION}-slim AS builder

RUN apt-get update -y && \
        apt-get upgrade -y && \
        apt-get install -y --no-install-recommends \
            tar \
            python3 \
            python3-dev \
            python3-venv \
            python3-pip && \
        apt-get clean -y && \
        apt-get autoclean -y

WORKDIR /.root

ARG BOUNCA_RELEASE=0.4.5
COPY bounca-${BOUNCA_RELEASE}.tar.gz /tmp/
RUN mkdir -p /srv/www/bounca tar && \
    tar -xf /tmp/bounca-${BOUNCA_RELEASE}.tar.gz -C /srv/www/

WORKDIR /srv/www/bounca
RUN python3 -m venv env && \
    . env/bin/activate && \
    pip install -r requirements.txt && \
    chown www-data:www-data -R /srv/www/bounca

FROM debian:${DEBIAN_VERSION}-slim

RUN apt-get update -y && \
        apt-get upgrade -y && \
        apt-get install -y --no-install-recommends \
            gettext \
            python3 \
            uwsgi-plugin-python3 \
            uwsgi \
            python3-dev \
            postgresql \
            postgresql-contrib && \
        apt-get clean -y && \
        apt-get autoclean -y

RUN mkdir -p /etc/uwsgi /etc/bounca
COPY --from=builder /srv/www/bounca/ /srv/www/bounca

RUN grep -vE '(socket|logto) =' /srv/www/bounca/etc/uwsgi/bounca.ini > /etc/uwsgi/bounca.ini && \
    rm -rf /srv/www/bounca/etc/

RUN mkdir -p /var/log/bounca/ && chown www-data:www-data -R /var/log/bounca/
ENTRYPOINT [ "/usr/bin/uwsgi", "--plugins", "python3,http", "--http", ":8080", "--master", "--ini", "/etc/uwsgi/bounca.ini", \
             "--log-x-forwarded-for", "--log-master", "--die-on-term", "--processes", "4", \
             "--static-map", "/static=/srv/www/bounca/media/static", \
             "--static-map", "/=/srv/www/bounca/front/dist", \
             "--static-index", "index.html"] 