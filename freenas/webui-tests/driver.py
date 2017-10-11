#/usr/bin/env python

from source import *
from login import run_login_test
from group import run_create_group_test
from user import run_create_user_test
from os import path
from selenium import webdriver

caps = webdriver.DesiredCapabilities().FIREFOX
caps["marionette"] = False
global driver
driver = webdriver.Firefox(capabilities=caps)
driver.implicitly_wait(30)
driver.maximize_window()
#driver.get(baseurl)



#starting the test and genewratinf result
run_login_test(driver)
run_create_user_test(driver)
run_create_group_test(driver)

