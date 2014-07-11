{View} = require 'atom'
#refer to https://github.com/atom/markdown-preview
jsyaml = require 'js-yaml'
fs = require 'fs'

module.exports =
class SaviorsEditorView extends View
  @content: ->
    @div class: 'saviors-editor', =>
      @canvas outlet: "canvas", width: '200', height: '200'
      @div outlet: "mbox", class: "mbox", =>
        @div "Nothing"

  initialize: (serializeState) ->
    atom.workspaceView.command "saviors-editor:toggle", => @toggle()

  # Returns an object that can be retrieved when package is activated
  serialize: ->

  # Tear down any state and detach
  destroy: ->
    @detach()

  toggle: ->
    console.log "SaviorsEditorView was toggled!"

    editor = atom.workspace.activePaneItem

    if @hasParent()
      @unsubscribe editor.getBuffer()
      @detach()
    else
      @subscribe editor.getBuffer(), 'contents-modified', =>
        @render(@getText())
      @render(@getText())
      atom.workspaceView.appendToRight(this)

  render: (data) ->
    @clearMessage()

    dir = atom.workspace.activePaneItem.getPath().match(/.*\//)[0]
    if data == null
      @popMessage "Not a valid YAML file!"
      return
    if data["tilemap"] == null
      @popMessage "Tilemap reference not found!"
      return

    # open the tilemap file
    level = @readLevel(dir + data["tilemap"])
    width = @canvas[0].width = level.width * 10
    height = @canvas[0].height = level.height * 10

    ctx = @canvas[0].getContext('2d')
    ctx.fillStyle = 'white'
    ctx.fillRect 0, 0, width, height

    ctx.fillStyle = 'green'
    for y in [0...level.height]
      for x in [0...level.width]
        id = level.content[y][x]
        if id == 0
          ctx.fillRect x * 10, y * 10, 10, 10

    if data.AI?
      for a in data.AI
        if a.path?
          for v in a.path
            v.x = v.x * 10 + 5
            v.y = v.y * 10 + 5

          ctx.strokeStyle = "blue"
          ctx.beginPath()
          ctx.moveTo(a.path[0].x, a.path[0].y)
          for v in a.path[1..]
            ctx.lineTo(v.x, v.y)
          ctx.stroke()

          for v in a.path
            if v.stop
              ctx.beginPath()
              ctx.arc v.x, v.y, 5, 0, 2 *Math.PI
              ctx.stroke()


  readLevel: (levelFileName) ->
    levelXML = fs.readFileSync(levelFileName)
    parser = new DOMParser()
    dom = parser.parseFromString(levelXML, "text/xml")
    if dom.documentElement.nodeName == "parsererror"
      console.log "error while parsing"
      return null
    layer = dom.getElementsByTagName('Layer')[0]
    if layer == null
      console.log "no layer xml node!"
      return
    arr = layer.textContent.split("\n").map((r) ->
      r.split(" ").map((i) -> parseInt i))

    level =
      width: arr[0].length
      height: arr.length
      content: arr

    return level

  getText: ->
    text = atom.workspace.activePaneItem.getText()
    try
      doc = jsyaml.safeLoad text
      return doc
    catch error
      console.log error
      return null

  popMessage: (msg) ->
    @mbox.css(display: "block")
    @mbox.find('div').text msg

  clearMessage: (msg) ->
    @mbox.css(display: "none")
