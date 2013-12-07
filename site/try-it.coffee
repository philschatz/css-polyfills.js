require [
  'jquery'
  'cs!polyfill-path/index'
  'ace/ace'
  'ace/mode/less'
  'ace/mode/html'
], ($, CSSPolyfill, ace, CSSMode, HTMLMode) ->

  # initModal
  $tryItModal = $('#try-it-modal')

  $cssEditor = $tryItModal.find('.css-editor')
  $htmlEditor = $tryItModal.find('.html-editor')
  $preview = $tryItModal.find('.preview')
  $runReloadButton = $tryItModal.find('.run-reload')

  cssEditor = ace.edit($cssEditor[0])
  cssEditor.setTheme("ace/theme/kr_theme")

  htmlEditor = ace.edit($htmlEditor[0])
  htmlEditor.setTheme("ace/theme/kr_theme")

  cssSession = cssEditor.getSession()
  htmlSession = htmlEditor.getSession()

  cssSession.setMode(new CSSMode.Mode())
  htmlSession.setMode(new HTMLMode.Mode())

  loadPreview = () ->
    $preview.html(htmlSession.getValue())
    $runReloadButton.removeClass('trying-it')

  htmlSession.on 'change', () -> loadPreview()
  cssSession.on  'change', () -> loadPreview()
  loadPreview()

  $runReloadButton.on 'click', () ->
    $runReloadButton.toggleClass('trying-it')

    if $runReloadButton.hasClass('trying-it')
      cssStyle = cssSession.getValue()
      CSSPolyfill $preview, cssStyle, (err, newCSS) ->
        if err
          alert("Looks like the CSS is not well-formed. Please correct it (maybe a missing semicolon?) Details: #{err}")
        else
          console.log('CSS after the polyfills ran:')
          console.log(newCSS)

    else
      loadPreview()


  $('.launch-it').on 'click', (evt) ->
    $tryItExample = $(evt.target).closest('.try-it-example')
    cssText = $tryItExample.find('.css-editor code').text()
    htmlText = $tryItExample.find('.html-editor').text()

    cssSession.setValue(cssText)
    htmlSession.setValue(htmlText)

    $tryItModal.modal('show')
