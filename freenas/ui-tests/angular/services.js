// System services: SMB, SSH, etc
// Requires: accounts, storage, shares
'use strict';

const accounts = require('./accounts.js');

var services = new Object();

// List of services
services.services_list = Array(
  { 'webdav': function() { return services.webdav } }
);

// Each services.${servicename} should have an interface of:
//    start(), stop(), setUp(), tearDown(), tests()
services.webdav = new Object();

services.webdav.start = function() {
  describe('webdav service', function() {
    it('should start', function() {
      browser.get('#/pages/services');
      browser.wait(function() {
        return browser.driver.getCurrentUrl().then(function(actualUrl) {
          return actualUrl.indexOf('#/pages/services') >= 0;
        }); 
      }, 30000);

      browser.wait(protractor.ExpectedConditions.presenceOf($('button.btn.btn-primary')), 30000);

      var btn_el = $$('button.btn.btn-primary').get(15);
      btn_el.isPresent();
      btn_el.click();

      // @TODO - figure out a way to wait for the 'loading' dialog to complete
      // while waiting for the service to start instead of an arbitrary sleep()
      browser.driver.sleep('5000');
      expect(btn_el.getText()).toEqual('Stop');
    });
  });

  return true;
};

services.webdav.stop = function() {
  describe('webdav service', function() {
    it('should stop', function() {
      browser.get('#/pages/services');
      browser.wait(function() {
        return browser.driver.getCurrentUrl().then(function(actualUrl) {
          return actualUrl.indexOf('#/pages/services') >= 0;
        });
      }, 30000);

      browser.wait(protractor.ExpectedConditions.presenceOf($('button.btn.btn-primary')), 30000);

      var btn_el = $$('button.btn.btn-primary').get(15);
      btn_el.isPresent();
      btn_el.click();

      // @TODO - figure out a way to wait for the 'loading' dialog to complete
      // while waiting for the service to stop instead of an arbitrary sleep()
      browser.driver.sleep('5000');
      expect(btn_el.getText()).toEqual('Start');
    });
  });

  return true;
};

services.webdav.setUp = function() {
  // start service
  // create dataset for share
  // create webdav share
  // verify webdav share access, read/write (?)
  // TODO: storage.create(dataset_name, dataset_type);
  //accounts.require_login();
  accounts.login();
  services.webdav.start();
};

services.webdav.tearDown = function() {
  // stop service
  // destroy dataset for share
  services.webdav.stop();
  // TODO: storage.destroy(dataset_name, dataset_type);
  accounts.logout();
};

services.webdav.tests = function() {
  var self = this;

  self.setUp();
  self.tearDown();

  return true;
};

services.tests = function() {
  services.webdav.tests();
};

services.tests();
module.exports = services;
