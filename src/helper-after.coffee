@define = @__polyfills_originalGlobals['define']

# if amd was loaded then register css-polyfills
@define?('polyfill-path/index', () -> @CSSPolyfills)


@__polyfills_originalGlobals = undefined
