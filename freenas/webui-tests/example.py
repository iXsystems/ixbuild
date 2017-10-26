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


class create_nameofthetest(unittest.TestCase):
    @classmethod
    def setUpClass(inst):
        driver.implicitly_wait(30)
        pass

    #Test navigation Account>Users>Hover>New User and enter username,fullname,password,confirmation and wait till user is  visibile in the list
    def test_01_nameofthe_testcase(self):
        #Click an element indirectly
        a = driver.find_element_by_xpath("XPATH1")
        a.click()
        #allowing page to load by giving explicit time(in seconds)
        time.sleep(1)
        #Click an element directly
        driver.find_element_by_xpath("XPATH2").click()

        #Checking and executing if the condition is true
        if self.is_element_present(By.XPATH,"XPATH"): 
            driver.find_element_by_xpath("XPATH").click()

        #scroll down to find an element
        driver.find_element_by_tag_name('html').send_keys(Keys.END)
        #give some sleep time

        #Perform HOVER 
        hover_element = driver.find_element_by_xpath("XPATH OF THE HOVER ELEMENT")
        hover = ActionChains(driver).move_to_element(hover_element)
        hover.perform()
        time.sleep(1)

        #Enter in a textbox using an external variable
        driver.find_element_by_xpath("XPATH OF THE TEXTBOX").send_keys(EXTERNAL_VARIABLE)
        #Enter in a textbox without a variable
        driver.find_element_by_xpath("XPATH OF THE TEXTBOX").send_keys("STRING TO BE ENTERED")
        #check if an element is found, if not display an ERROR
        self.assertTrue(self.is_element_present(By.XPATH, "XPATH OF THE ELEMENT TO BE FOUND"), "ERROR")


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
        #if not the last module
        pass
        #if it is the last module
        #driver.close()

def run_create_nameofthetest(webdriver):
    global driver
    driver = webdriver
    suite = unittest.TestLoader().loadTestsFromTestCase(create_nameofthetest)
    unittest.TextTestRunner(verbosity=2).run(suite)
