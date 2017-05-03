// System storage: volumes, snapshots
'use strict';

//const html_dnd = require('html-dnd').code;
const accounts = require('./accounts.js');

var storage = new Object();

storage.volumes = new Object();

storage.volumes.create = function() {
  var self = this;
  describe('storage volume', function() {
    it('should be added', function() {
      browser.get('#/pages/storage/volumes/manager');
      browser.wait(function() {
        return browser.driver.getCurrentUrl().then(function(actualUrl) {
          return actualUrl.indexOf('#/pages/storage/volumes/manager') >= 0;
        }); 
      }, 6000);

      var vol_name_el = $('input.form-control');
      vol_name_el.sendKeys('testvol');

      var disk_el = $$('app-disk').first();
      var groups_el = $$('app-vdev > ba-card > div > div > div').first();
      disk_el.isPresent();
      groups_el.isPresent();

      expect(disk_el.getText()).toContain('ada1');

      //browser.executeScript(html_dnd, disk_el.getWebElement(), groups_el.getWebElement());
      //browser.actions().dragAndDrop(dest_disk_el.getWebElement(), {x:1000, y:1000}).perform();
      //browser.actions().mouseDown(disk_el.getWebElement()).mouseMove(groups_el.getWebElement()).mouseUp().perform();
      browser.actions().dragAndDrop(disk_el.getWebElement(), groups_el.getWebElement()).perform();

      browser.debugger();
      browser.driver.sleep(20000);
      browser.pause();
    });
    //it('should populate the storage list with the new volume', function() {
    //  
    //});
  });

  return true;
};

storage.snapshots = new Object();

storage.tests = function() {
  var self = this;

  accounts.login();
  self.volumes.create();

  return true;
};

module.exports = storage;
