require.config({
    //baseUrl: ,
    paths: {
      'polyfill-path': './src',
      'cs':            './bower_components/require-cs/cs',
      'coffee-script': './bower_components/coffee-script/extras/coffee-script',
      'underscore':    './bower_components/underscore/underscore',
      'jquery':        './bower_components/jquery/jquery',
      'less':          './node_modules/less/test/browser/less'
    },
    shim: {
      'underscore': {
        exports: '_'
      },
      'less': {
        exports: 'less'
      },
    },
});
