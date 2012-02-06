#!/usr/bin/env bash
source `dirname "$0"`/lib.sh && init || exit 1

ods_reset_env ()
{
    echo "ods_reset_env: resetting OpenDNSSEC environment"
    echo "y" | ods-ksmutil setup &&
    log_this softhsm-init-token softhsm --init-token --slot 0 --label OpenDNSSEC --pin 1234 --so-pin 1234 ||
    return 1

    if ! log_grep softhsm-init-token stdout "The token has been initialized."; then
        return 1
    fi
}

require opendnssec

check_if_tested opendnssec && exit 0
start_test opendnssec

test_ok=0
(
    run_tests test.dnsadapters
) &&
test_ok=1

if [ "$test_ok" -eq 1 ]; then
    set_test_ok opendnssec || exit 1
    exit 0
fi

exit 1
