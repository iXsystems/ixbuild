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

xpaths = { 'usernameTxtBox' : "//input[@id='inputUsername']",
           'passwordTxtBox' : "//input[@id='md-input-3']",
          'submitButton' : "/html/body/app/main/login/div/div/form/div[3]/div[1]/button",
          'newUser' : "//*[@id='md-input-7']",
         'newUserName' : "//*[@id='md-input-13']",
         'newUserPass' : "//*[@id='md-input-17']",
        'newUserPassConf' : "//*[@id='md-input-19']"
        }

class run_login_test(unittest.TestCase):
    @classmethod
    def setUpClass(inst):
        #create a new Firefox session
        caps = webdriver.DesiredCapabilities().FIREFOX
        caps["marionette"] = False
        inst.driver = webdriver.Firefox(capabilities=caps)
        inst.driver.implicitly_wait(30)
        inst.driver.maximize_window()
        inst.driver.get(baseurl)
        #inst.driver = webdriver.Remote(command_executor=executor_url, desired_capabilities={})
        #inst.driver.session_id = session_id


  #Tests in numerals in order to sequence the tests
  #Test enter username,password,login and check successfully login
    def test_1_login(self):
        #enter username in the username textbox
        #self.driver.find_element_by_xpath(xpaths['usernameTxtBox']).send_keys(username)
        #enter password in the password textbox
        self.driver.find_element_by_xpath(xpaths['passwordTxtBox']).send_keys(password)
        #click
        #click
        self.driver.find_element_by_xpath("/html/body/app-root/app-auth-layout/app-signin/div/div/md-card/md-card-content/form/button").click()
        #check if the dashboard opens
        self.assertTrue(self.is_element_present(By.XPATH,"/html/body/app-root/app-admin-layout/md-sidenav-container/div[6]/app-breadcrumb/div"),"Unsuccessful Login")

    # Next step-- To check if the new user is present in the list via automation


  #method to test if an element is present
    def is_element_present(self, how, what):
        """
        Helper method to confirm the presence of an element on page
        :params how: By locator type
        :params what: locator value
        """
        try: self.driver.find_element(by=how, value=what)
        except NoSuchElementException: return False
        return True

    @classmethod
    def tearDownClass(inst):
        inst.driver.close()

#unittest.main(verbosity=2)
