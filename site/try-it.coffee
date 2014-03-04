require [
  'jquery'
  'cs!polyfill-path/index'
  'ace/ace'
  'ace/mode/less'
  'ace/mode/html'
], ($, CSSPolyfills, ace, CSSMode, HTMLMode) ->

  # initModal
  $tryItModal = $('#try-it-modal')

  $cssEditor = $tryItModal.find('.css-editor')
  $htmlEditor = $tryItModal.find('.html-editor')
  $preview = $tryItModal.find('.preview')
  $previewStyle = $tryItModal.find('style')
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

  # For some reason this file is being loaded twice by requirejs so make
  # sure the click handlers are only added once.
  $runReloadButton.off('click.css-polyfills')
  $runReloadButton.on 'click.css-polyfills', () ->
    $runReloadButton.toggleClass('trying-it')

    if $runReloadButton.hasClass('trying-it')
      cssStyle = cssSession.getValue()
      p = new CSSPolyfills()
      p.run $preview, cssStyle, 'STDINPUT', (err, newCSS) ->
        if err
          alert("Looks like the CSS is not well-formed. Please correct it (maybe a missing semicolon?) Details: #{err}")
        else
          $previewStyle.text(newCSS)

    else
      loadPreview()


  $('.launch-it').off('click.css-polyfills')
  $('.launch-it').on 'click.css-polyfills', (evt) ->
    $tryItExample = $(evt.target).closest('.try-it-example')
    cssText = $tryItExample.find('.css-editor code').text()
    htmlText = $tryItExample.find('.html-editor').text()

    cssSession.setValue(cssText)
    htmlSession.setValue(htmlText)

    $tryItModal.modal('show')
