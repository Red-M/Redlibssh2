#!/usr/bin/env python3
# Monkey patch to not ship openssl in pypi wheels ( https://github.com/DIPlib/diplib/blob/master/tools/travis/auditwheel )
import sys

from auditwheel.main import main
from auditwheel.policy import _POLICIES as POLICIES

# libjvm is loaded dynamically; do not include it
for p in POLICIES:
    p['lib_whitelist']+=[
        'libssl.so',
        'libcrypto.so'
    ]

if __name__ == "__main__":
    sys.exit(main())
