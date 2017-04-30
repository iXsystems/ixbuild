// System services: SMB, SSH, etc
// Requires: accounts, storage, shares
'use strict';

// http://stackoverflow.com/questions/36201691/protractor-angular-2-failed-unknown-error-angular-is-not-defined
browser.ignoreSynchronization = true;

require('./accounts');

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
      browser.get('#/pages/services');

      let l = element.all(by.css('.btn-primary'));
      l[15].click();

      expect(l[15].getText()).equalTo('Stop');
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
  return null;
};

services.webdav.tearDown = function() {
  // stop service
  // destroy dataset for share
  return null;
};

services.webdav.tests = function() {
  var self = this;

  expect('Configuring a webdav share', function() {
    it('should have a logged in user account', function() {
      expect(account.login()).toEqual(true);
    });
    it('should have a dataset available for sharing', function() {
      // TODO: storage.create(dataset_name, dataset_type);
      expect(true).toEqual(true);
    });
  });
};

// restore
browser.ignoreSynchronization = false;
