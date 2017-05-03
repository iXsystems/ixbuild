exports.config = {
  framework: 'jasmine2',
  specs: ['spec.js'],
  onPrepare: function() {
    browser.ignoreSynchronization = true;
  },
  useAllAngular2AppRoots: true,
  debug: true
};
