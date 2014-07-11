SaviorsEditorView = require './saviors-editor-view'

module.exports =
  saviorsEditorView: null

  activate: (state) ->
    @saviorsEditorView = new SaviorsEditorView(state.saviorsEditorViewState)

  deactivate: ->
    @saviorsEditorView.destroy()

  serialize: ->
    saviorsEditorViewState: @saviorsEditorView.serialize()
