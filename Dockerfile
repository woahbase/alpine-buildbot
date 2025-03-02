# syntax=docker/dockerfile:1
#
ARG IMAGEBASE=frommakefile
#
FROM ${IMAGEBASE}
#
ARG VERSION=3.11.9
ARG BUILDBOT_ROLE=master
# no need to specify role in containers, master/worker role is
# determined based on which image is run
#
ENV \
    BUILDBOT_HOME=/home/alpine/buildbot \
    BUILDBOT_ROLE=${BUILDBOT_ROLE:-worker} \
    CRYPTOGRAPHY_DONT_BUILD_RUST=1
#
RUN set -xe \
    && apk add --no-cache -Uu --purge \
        ca-certificates \
        libffi \
        openssl \
        py3-certifi \
        py3-cffi \
        py3-six \
        tzdata \
    && apk add --no-cache -uU --virtual .build-dependencies \
        build-base \
        cargo \
        libffi-dev \
        openssl-dev \
        python3-dev \
    && pip install --no-cache-dir --upgrade --break-system-packages \
        setuptools \
        wheel \
# for master
    && if [ "${BUILDBOT_ROLE}" = "master" ]; then \
        echo "Installing buildmaster dependencies" \
        # reference:
        #   https://github.com/buildbot/buildbot/blob/master/Dockerfile.master
        && apk add --no-cache -uU \
            # for generating PNG badges
            cairo \
            # cairo-gobject \
            py3-cairo \
            # for buildbot-badges
            py3-pillow \
            # for posgres db
            libpq \
            py3-psycopg2 \
            # for pass-based secrets
            pass \
            # for loading yaml configuration files
            py3-yaml \
        \
        && apk add --no-cache -uU --virtual .build-dependencies-master \
            # # for generating PNG badges
            # cairo-dev \
            glib-dev \
            # for buildbot-badges->pillow
            libjpeg-turbo-dev \
            # for posgres db
            libpq-dev \
        \
        && pip install --no-cache-dir --break-system-packages \
            buildbot[bundle,tls]==${VERSION} \
            PyMySQL \
            # for http/misc
            requests \
            txrequests \
            # for ldap userinfo provider
            ldap3 \
            # for generating badges SVG/PNG
            buildbot-badges \
            # for custom dashboards
            buildbot-wsgi-dashboards \
            flask \
            # for docker latent worker
            docker \
            # # for libvirt latent worker (requires libvirt-dev)
            # libvirt-python \
            # for prometheus metrics
            buildbot_prometheus \
            # for vault secrets
            hvac \
        \
        && apk del --purge .build-dependencies-master \
        || exit 1; \
# for worker
    elif [ "${BUILDBOT_ROLE}" = "worker" ]; then \
        echo "Installing buildworker dependencies" \
        # reference:
        #   https://github.com/buildbot/buildbot/blob/master/worker/Dockerfile
        # && apk add --no-cache -uU \
        # \
        # && apk add --no-cache -uU --virtual .build-dependencies-worker \
        # \
        && pip install --no-cache-dir --break-system-packages \
            twisted[tls] \
            buildbot-worker==${VERSION} \
            requests\
        \
        # && apk del --purge .build-dependencies-worker; \
        || exit 1; \
    fi \
#
    && apk del --purge .build-dependencies \
    # ensure these packages are installed in both images
    && apk add --no-cache -uU \
        curl \
        bind-tools \
        drill \
        git \
        make \
        openssh \
    && rm -rf /var/cache/apk/* /tmp/* /root/.cache /root/.cargo
#
COPY root/ /
#
VOLUME ${BUILDBOT_HOME}
#
# WORKDIR ${BUILDBOT_HOME}
#
EXPOSE 8010/tcp 9989 9990 9991
#
HEALTHCHECK \
    --interval=2m \
    --retries=5 \
    --start-period=5m \
    --timeout=10s \
    CMD \
    wget --quiet --tries=1 --no-check-certificate --spider ${HEALTHCHECK_URL:-"http://${BUILDBOT_MASTERADDRESS:-localhost}:8010/"} || exit 1
#
ENTRYPOINT ["/init"]
