#!/usr/bin/env python

# Author: Eric Turgeon
# License: BSD

import requests
from config import freenas_url

def test():
    authtest = requests.get(freenas_url + 'account/users/',
                 auth=('root', 'abcd1234'))
    response = authtest.status_code
    assert response == 200

