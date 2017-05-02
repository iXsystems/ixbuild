exports.config = {
  framework: 'jasmine2',
  specs: ['accounts.js', 'services.js'],
  onPrepare: function() {
    browser.ignoreSynchronization = true;
  },
  useAllAngular2AppRoots: true
};
