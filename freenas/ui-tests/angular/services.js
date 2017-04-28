// System services: SMB, SSH, etc
// Requires: accounts, storage, shares
require('./accounts');

var services = new Object();

// List of services
services.services_list = function() {
  var self = this;

  let services_list = {
    'webdav': self.webdav
  };

  return services_list;
};

// Each services.${servicename} should have an interface of:
//    start(), stop(), restart()
//    setUp(), test(), tearDown()
services.webdav = new Object();

services.webdav.start = function() {
  return null;
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
  // teardown webdav share
  // destroy dataset for share
  // stop service
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
