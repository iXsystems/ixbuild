#/usr/bin/env python
# Author: Eric Turgeon
# License: BSD

from source import *
from login import run_login_test
from guide import run_guide_test
from group import run_create_group_test
from user import run_create_user_test
from ssh import run_configure_ssh_test
from logout import run_logout_test
from os import path
from selenium import webdriver
#from example import run_creat_nameofthetest

def webDriver():
    caps = webdriver.DesiredCapabilities().FIREFOX

    caps["marionette"] = False
    global driver
    driver = webdriver.Firefox(capabilities=caps)
    driver.implicitly_wait(30)
    driver.maximize_window()
    return driver

