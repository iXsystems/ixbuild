#!/usr/bin/env sh
CURRDIR="$(realpath "$(dirname "$0")")"

/usr/bin/env python "${CURRDIR}/login.py" &>/dev/null
