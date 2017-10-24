#!/usr/bin/env python3.6

# Author: Eric Turgeon
# License: BSD

import unittest
from functions import POST, GET_OUTPUT


class debug_test(unittest.TestCase):

    def test_01_Creating_diagnostic_file(self):
        payload = {"name": "newbe1", "source": "default"}
        assert PUT("system/debug/",payload) == 200

    def test_02_Verify_that_API_returns_WWW_download_path(self):
        assert GET_OUTPUT("/system/debug/download/", "url") == "/system/debug/download/"


if __name__ == "__main__":
    unittest.main(verbosity=2)
