# Author: Rishabh Chauhan
# License: BSD
# Location for tests  of FreeNAS new GUI
#Test case count: 2

from source import *
from selenium.webdriver.common.keys import Keys
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
        'newUserPassConf' : "//*[@id='md-input-19']",
        'newGroupName' : "//*[@id='md-input-25']"
        }

class configure_ssh_test(unittest.TestCase):
    @classmethod
    def setUpClass(inst):
        driver.implicitly_wait(30)
        pass

    #Test navigation Account>Users>Hover>New User and enter username,fullname,password,confirmation and wait till user is  visibile in the list
    def test_01_turnon_ssh (self):
        time.sleep(5)
        #Click Service Menu
        driver.find_element_by_xpath("//*[@id='scroll-area']/navigation/md-nav-list/div[9]/md-list-item/div/a").click()
        #scroll down
        driver.find_element_by_tag_name('html').send_keys(Keys.END)
        time.sleep(2)
        #check if the element is present
        self.assertTrue(self.is_element_present(By.XPATH,"//*[@id='md-slide-toggle-14-input']"),"ssh toggle not found")

        #Click on the ssh toggle button
        driver.find_element_by_xpath("//*[@id='md-slide-toggle-14-input']").click()
 
       #Check if the status is turned on
        #driver.find_element_by_xpath("/html/body/app-root/app-admin-layout/md-sidenav-container/div[6]/div/services/div/service[11]/md-card/md-list/md-list-item[1]/div/p/em")

        #Check if the status is on
        #self.assertTrue(self.is_element_present(By.XPATH,"/html/body/app-root/app-admin-layout/md-sidenav-container/div[6]/div/services/div/service[11]/md-card/md-list/md-list-item[1]/div/p/em"),"Unsuccessful Login")



        # Next step-- To check if the new user is present in the list via automation


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


def run_configure_ssh_test(webdriver):
    global driver
    driver = webdriver
    suite = unittest.TestLoader().loadTestsFromTestCase(configure_ssh_test)
    unittest.TextTestRunner(verbosity=2).run(suite)
