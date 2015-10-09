require.config({
    //baseUrl: ,
    paths: {
      'polyfill-path': './src',
      'cs':            './bower_components/require-cs/cs',
      'coffee-script': './bower_components/coffee-script/extras/coffee-script',
      'underscore':    './bower_components/underscore/underscore',
      'jquery':        './bower_components/jquery/dist/jquery',
      'sizzle':        './bower_components/sizzle/dist/sizzle',
      'less':          './node_modules/less/dist/less-1.6.0',
      'eventemitter2': './bower_components/eventemitter2/lib/eventemitter2',
      'selector-set':  './bower_components/selector-set/selector-set'
    },
    shim: {
      'underscore': {
        exports: '_'
      },
      'less': {
        exports: 'less'
      },
      'selector-set': {
        dependencies: ['jquery'],
        exports: 'SelectorSet'
      }
    },
});
