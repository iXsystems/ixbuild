#!/usr/bin/env python
# Author: Rishabh Chauhan
# License: BSD
# Location for tests  of FreeNAS new GUI
#Test case count: 2

from source import *
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.remote.webdriver import WebDriver as RemoteWebDriver
from selenium import webdriver
from selenium.webdriver.support.ui import Select
from selenium.webdriver.common.by import By
from selenium.common.exceptions import ElementNotVisibleException
from selenium.common.exceptions import NoSuchElementException
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.action_chains import ActionChains


import time
import unittest
import random
try:
    import unittest2 as unittest
except ImportError:
    import unittest

xpaths = { 'usernameTxtBox' : "//input[@id='md-input-1']",
           'passwordTxtBox' : "//input[@id='md-input-3']",
          'submitButton' : "/html/body/app/main/login/div/div/form/div[3]/div[1]/button",
          'newUser' : "//*[@id='md-input-7']",
         'newUserName' : "//*[@id='md-input-13']",
         'newUserPass' : "//*[@id='md-input-17']",
        'newUserPassConf' : "//*[@id='md-input-19']"
        }

class login_test(unittest.TestCase):
    @classmethod
    def setUpClass(inst):
        driver.get(baseurl)


    #Tests in numerals in order to sequence the tests
    #Test enter username,password,login and check successfully login
    def test_01_login(self):
        #enter username in the username textbox
        driver.find_element_by_xpath(xpaths['usernameTxtBox']).clear()
        driver.find_element_by_xpath(xpaths['usernameTxtBox']).send_keys(username)
        #enter password in the password textbox
        driver.find_element_by_xpath(xpaths['passwordTxtBox']).send_keys(password)
        #click
        driver.find_element_by_xpath("/html/body/app-root/app-auth-layout/app-signin/div/div/md-card/md-card-content/form/button").click()
        #check if the dashboard opens
        self.assertTrue(self.is_element_present(By.XPATH,"/html/body/app-root/app-admin-layout/md-sidenav-container/div[6]/app-breadcrumb/div"),"Unsuccessful Login")

        #cancelling the tour
        if self.is_element_present(By.XPATH,"/html/body/div[3]/div[1]/button"): 
            driver.find_element_by_xpath("/html/body/div[3]/div[1]/button").click()

    #method to test if an element is present
    def is_element_present(self, how, what):
        """
        Helper method to confirm the presence of an element on page
        :params how: By locator type
        :params what: locator value
        """
        try: driver.find_element(by=how, value=what)
        except NoSuchElementException: return False
        return True

    @classmethod
    def tearDownClass(inst):
        #driver.close()
        pass

def run_login_test(webdriver):
    global driver
    driver = webdriver
    suite = unittest.TestLoader().loadTestsFromTestCase(login_test)
    unittest.TextTestRunner(verbosity=2).run(suite)
