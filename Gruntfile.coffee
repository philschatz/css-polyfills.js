module.exports = (grunt) ->

  fs = require('fs')
  pkg = require('./package.json')

  # Project configuration.
  grunt.initConfig
    pkg: pkg

    # Compile CoffeeScript to JavaScript
    coffee:
      compile:
        options:
          sourceMap: false # true
        files:
          'dist/helper-before.js': ['src/helper-before.coffee']
          'dist/helper-after-libs.js': ['src/helper-after-libs.coffee']
          'dist/css-polyfills-coffee.js': [
            # The order of these is important because we use a much simpler AMD loader than RequireJS
            'src/selector-tree.coffee'
            'src/fixed-point-runner.coffee'
            'src/selector-visitor.coffee'
            'src/extras.coffee'
            'src/plugins.coffee'
            'src/less-converters.coffee'
            'src/index.coffee'
          ]
          'dist/helper-after.js': ['src/helper-after.coffee']

    concat:
      dist:
        src: [
            'dist/helper-before.js'

            'bower_components/underscore/underscore.js'
            'bower_components/sizzle/dist/sizzle.js'
            'node_modules/less/dist/less-1.6.0.js'
            'src/jquery-selectors.js'
            'bower_components/eventemitter2/lib/eventemitter2.js'
            'bower_components/selector-set/selector-set.js'

            'dist/helper-after-libs.js'
            'dist/css-polyfills-coffee.js'
            'dist/helper-after.js'
        ]
        dest: 'dist/css-polyfills.js'

    # Release a new version and push upstream
    bump:
      options:
        commit: true
        push: true
        pushTo: ''
        commitFiles: ['package.json', 'bower.json', 'dist/css-polyfills.js']
        # Files to bump the version number of
        files: ['package.json', 'bower.json']


  # Dependencies
  # ============
  for name of pkg.dependencies when name.substring(0, 6) is 'grunt-'
    grunt.loadNpmTasks(name)
  for name of pkg.devDependencies when name.substring(0, 6) is 'grunt-'
    if grunt.file.exists("./node_modules/#{name}")
      grunt.loadNpmTasks(name)

  # Tasks
  # =====

  # Default
  # -----
  grunt.registerTask 'default', [
    'coffee'
    'concat:dist'
  ]
