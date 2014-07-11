{WorkspaceView} = require 'atom'
SaviorsEditor = require '../lib/saviors-editor'

# Use the command `window:run-package-specs` (cmd-alt-ctrl-p) to run specs.
#
# To run a specific `it` or `describe` block add an `f` to the front (e.g. `fit`
# or `fdescribe`). Remove the `f` to unfocus the block.

describe "SaviorsEditor", ->
  activationPromise = null

  beforeEach ->
    atom.workspaceView = new WorkspaceView
    activationPromise = atom.packages.activatePackage('saviors-editor')

  describe "when the saviors-editor:toggle event is triggered", ->
    it "attaches and then detaches the view", ->
      expect(atom.workspaceView.find('.saviors-editor')).not.toExist()

      # This is an activation event, triggering it will cause the package to be
      # activated.
      atom.workspaceView.trigger 'saviors-editor:toggle'

      waitsForPromise ->
        activationPromise

      runs ->
        expect(atom.workspaceView.find('.saviors-editor')).toExist()
        atom.workspaceView.trigger 'saviors-editor:toggle'
        expect(atom.workspaceView.find('.saviors-editor')).not.toExist()
