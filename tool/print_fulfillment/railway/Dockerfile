FROM ubuntu:24.04

# Runtime archives are exact versions with SHA256 checks in runtime-pins.json.
# Credentials are supplied only at deployment runtime, never as build arguments.
ENV DEBIAN_FRONTEND=noninteractive \
    PATH=/opt/node/bin:/opt/flutter/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    HOME=/home/snapfit-worker \
    PUB_CACHE=/home/snapfit-worker/.pub-cache \
    LANG=C.UTF-8 \
    FLUTTER_SUPPRESS_ANALYTICS=true \
    SNAPFIT_FLUTTER_BIN=/opt/flutter/bin/flutter \
    TMPDIR=/tmp/snapfit-print-worker

RUN test "$(dpkg --print-architecture)" = amd64 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       python3 ca-certificates curl git unzip xz-utils zip tini \
       libglu1-mesa libgl1 libegl1 libx11-6 libxext6 libxi6 libxrandr2 \
       libxcursor1 libxinerama1 libfontconfig1 \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --uid 10001 --shell /usr/sbin/nologin snapfit-worker \
    && mkdir -p /opt/node /app /tmp/snapfit-print-worker \
    && chmod 0700 /tmp/snapfit-print-worker

COPY tool/print_fulfillment/linux/runtime-pins.json /tmp/runtime-pins.json
COPY tool/print_fulfillment/railway/install_runtime.py /tmp/install_runtime.py
RUN python3 /tmp/install_runtime.py \
    && rm /tmp/install_runtime.py /tmp/runtime-pins.json \
    && chown -R snapfit-worker:snapfit-worker /opt/flutter /app /tmp/snapfit-print-worker

USER snapfit-worker
WORKDIR /app
COPY --chown=snapfit-worker:snapfit-worker pubspec.yaml pubspec.lock ./
COPY --chown=snapfit-worker:snapfit-worker packages/book_page_flip packages/book_page_flip
RUN flutter config --no-analytics \
    && flutter --no-version-check precache --linux \
    && flutter --no-version-check pub get --enforce-lockfile

COPY --chown=snapfit-worker:snapfit-worker lib lib
COPY --chown=snapfit-worker:snapfit-worker assets assets
COPY --chown=snapfit-worker:snapfit-worker tool/print_samples/redprinting_soft_sample.dart tool/print_samples/redprinting_soft_sample.dart
COPY --chown=snapfit-worker:snapfit-worker tool/print_fulfillment tool/print_fulfillment

# Fail the image build unless the real Linux Flutter engine makes both fixtures.
# These synthetic fixtures never authenticate, submit, charge, or approve a sale.
RUN node -- tool/print_fulfillment/railway/verify_image.mjs --build-fixtures

STOPSIGNAL SIGTERM
ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["/bin/sh", "tool/print_fulfillment/railway/start_worker.sh"]
