// System storage: volumes, snapshots
'use strict';

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

      var dest_disk_el = $$('app-disk').first();
      var dest_groups_el = $('app-vdev > ba-card > div > div > div');
      dest_disk_el.isPresent();
      dest_groups_el.isPresent();

      browser.actions().dragAndDrop(dest_disk_el, dest_groups_el).perform();

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

storage.tests();
module.exports = storage;
