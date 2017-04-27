import os

from selenium import webdriver

FNASURI="http://{}/".format(os.environ['FNASTESTIP'])

#browser = webdriver.Chrome()
browser = webdriver.Firefox()
browser.get(FNASURI)

password_elm = browser.find_element_by_id("id_password")
password_elm.send_keys("testing")

submit_btn = browser.find_element_by_id("dijit_form_Button_0_label")
submit_btn.click()

assert FNASURI in browser.current_url

assert len(browser.find_elements_by_id("btn_InitialWizardSettingsForm_Cancel_label")) in 1

browser.find_elements_by_id("btn_InitialWizardSettingsForm_Cancel_label").click()
