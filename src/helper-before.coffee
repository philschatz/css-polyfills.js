# Squirrel globals for 3rd party libs (if they were loaded before)

@__polyfills_originalGlobals ?=
  define:         @define
  underscore:     @_
  less:           @less
  eventemitter2:  @EventEmitter2
  SelectorSet:    @SelectorSet

# So 3rd party libs do not try to register with requirejs because they are concatenated into one file
@define = undefined
