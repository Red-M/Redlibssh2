#!/usr/bin/env python3
# Monkey patch to not ship openssl in pypi wheels ( https://github.com/DIPlib/diplib/blob/master/tools/travis/auditwheel )
import sys

from auditwheel.main import main
from auditwheel.policy import _POLICIES as POLICIES

for p in POLICIES:
    p['lib_whitelist']+=[
        'libssl.so.1.1',
        'libcrypto.so.1.1'
    ]

if __name__ == "__main__":
    sys.exit(main())
