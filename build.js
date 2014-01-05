({
  mainConfigFile: './config.js',
  //include: ['./node_modules/almond/almond'],
  include: ['./bower_components/requirejs/require'],
  stubModules: ['cs'],
  optimize: 'none',
  out: 'dist/css-polyfills.js',
  name: 'cs!polyfill-path/index',
})
