// requires: storage, shares

services = new Object();

// List of services
services.list_services = function(){
  var self = this;
  return {
    'webdav': self.webdav
  };
];

// Each service should have an interface of:
//    start(), stop(), restart()
//    setUp(), test(), tearDown()
services.webdav = new Object();

services.webdav.start = function(){
  return null;
};

services.webdav.stop = function(){
  return null;
};

services.webdav.restart = function(){
  return null;
};

services.webdav.setUp = function(){
  // start service
  // create dataset for share
  // create webdav share
  // verify webdav share access, read/write (?)
  return null;
};

services.webdav.tearDown = function(){
  // teardown webdav share
  // destroy dataset for share
  // stop service
  return null;
}

services.webdav.test_list = {
  var self = this;
  return new Array();
};

services.webdav.test = function(){
  // Run service.tests()
  //    Example:
  //    Perform timed tasks, like cronjobs (start, add job, wait, verify job in UI
  //    report, once all other services have completed their tests, stop each
  //    service in the reverse order in which it was started.
  return null;
};

// Interface functions:
//    Do user-realistic, live, tests, starting all services, preforming a series of
//    actions on each service, then finally closing all services and returning to a
//    torn-down state.
//    ---
//    service_list.start()
//      # Run async?
//      foreach service in service_list:
//         services.test()
//      endforeach
//      {run other tests() from angular UI tests}
//      eg: add user and groups
//          users and groups being assigned to SMB shared dataset
//          login user
//          cronjob user creating a system alert by newly created user
//          setup snapshot
//          logout user
//    services_list.stop()
