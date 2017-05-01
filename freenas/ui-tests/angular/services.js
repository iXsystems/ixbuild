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
//    start(), stop(), restart()
//    setUp(), test(), tearDown()
services.webdav = new Object();

services.webdav.start = function() {
  describe('webdav service', function() {
    it('should start', function() {
      browser.ignoreSynchronization = true;
      browser.get('#/pages/services');

      let services_list = $$('.btn-primary');
      services_list.isPresent();
      services_list[15].click();

      expect(l[15].getText()).equalTo('Stop');
      browser.ignoreSynchronization = false;
    });
  });

  return true;
};

services.webdav.stop = function() {
  return null;
};

services.webdav.restart = function() {
  return null;
};

services.webdav.setUp = function() {
  // start service
  // create dataset for share
  // create webdav share
  // verify webdav share access, read/write (?)
  accounts.login();
  // TODO: storage.create(dataset_name, dataset_type);
  services.webdav.start();
};

services.webdav.tearDown = function() {
  // stop service
  // destroy dataset for share
  service.webdav.stop();
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

// restore
browser.ignoreSynchronization = false;
module.exports = browser;
