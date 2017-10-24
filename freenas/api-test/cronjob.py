#!/usr/bin/env python3.6

# Author: Eric Turgeon
# License: BSD

import unittest
from functions import POST, GET_OUTPUT


class cronjob_test(unittest.TestCase):

    def test_01_Creating_new_cron_job_which_will_run_every_minute(self):
        payload = {"cron_user": "root",
                   "cron_command": "touch '/tmp/.testFileCreatedViaCronjob'",
                   "cron_minute": "*/1"}
        assert POST("/tasks/cronjob/", payload) == 201

    def test_02_Checking_to_see_if_cronjob_was_created_and_enabled(self):
        assert GET_OUTPUT("/tasks/cronjob/", "cron_enabled") == "true"


if __name__ == "__main__":
    unittest.main(verbosity=2)
