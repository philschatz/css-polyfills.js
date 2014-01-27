# Dependencies:

# index:
# - less-convert
# - plugins
# - extras
# - fixed-point

# less-convert:
# - selector-visitor

# plugins: none
# extras: none

# selector-visitor:
# - jquery-selectors

# fixed-point: none



# Prefill globally-defined modules

MODULES =
  underscore: @_
  jquery: @$
  less: @less
  eventemitter2: @EventEmitter2
  'polyfill-path/jquery-selectors': @$



@_              = @__polyfills_originalGlobals['underscore']
@jQuery = @$    = @__polyfills_originalGlobals['jquery']
@less           = @__polyfills_originalGlobals['less']
@EventEmitter2  = @__polyfills_originalGlobals['eventemitter2']


@define = (moduleName, deps, callback) ->
  args = for depName in deps
    [first, second] = depName.split('!')
    depName = second or first
    MODULES[depName]
  val = callback.apply(@, args)
  MODULES[moduleName] = val
  val
