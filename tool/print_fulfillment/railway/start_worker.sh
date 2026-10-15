#!/bin/sh
set -eu
umask 077
# Validation has no order/PG/supplier side effects. Failed credentials exit and
# are retried by the platform; private values never become command arguments.
node -- tool/print_fulfillment/railway/verify_image.mjs
node -- tool/print_fulfillment/run_worker.mjs --check-auth
exec node -- tool/print_fulfillment/run_worker.mjs
