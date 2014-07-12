{View} = require 'atom'
PathWatcher = require 'pathwatcher'
{Range, Point} = require 'text-buffer'
jsyaml = require 'js-yaml'
fs = require 'fs'

module.exports =
class SaviorsEditorView extends View
  TILE_SIZE: 10

  @content: ->
    @div class: 'saviors-editor', =>
      @div class: 'main-frame', =>
        @canvas outlet: "canvas", width: '200', height: '200'
        @canvas outlet: "overlay", class: "overlay-canvas"
      @div outlet: "mbox", class: "mbox", =>
        @div "Nothing"

  initialize: (serializeState) ->
    atom.workspaceView.command "saviors-editor:toggle", => @toggle()
    atom.workspaceView.command "saviors-editor:select-words", => @selectWords()

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
      if @tilemapWatcher?
        @tilemapWatcher.close()
        @tilemapWatcher = null
      @detach()
    else
      @subscribe editor.getBuffer(), 'contents-modified', =>
        @render(@getYAMLDoc(editor))
      @subscribe editor, 'cursors-moved', =>
        @renderCursor(editor)
      @render(@getYAMLDoc(editor))
      @renderCursor(editor)
      atom.workspaceView.appendToRight(this)

  render: (data) ->
    @clearMessage()

    editor = atom.workspace.activePaneItem
    dir = editor.getPath().match(/.*\//)[0]
    tileset = null

    unless data?
      @popMessage "Not a valid YAML file!"
      return
    unless data["tilemap"]?
      @popMessage "Tilemap reference not found!"
      return

    doit = =>
      # open the tilemap file
      tilemapPath = new PathWatcher.File(dir + data["tilemap"]).getPath()
      level = @readLevel(tilemapPath)

      unless level?
        @popMessage "Tilemap file not found or invalid!"
        return

      # set up file watcher for the level array file
      if @tilemapWatcher? and @tilemapWatcher.path != tilemapPath
        @tilemapWatcher.close()
        @tilemapWatcher = null

      unless @tilemapWatcher?
        @tilemapWatcher = PathWatcher.watch(tilemapPath, =>
          @render(@getYAMLDoc(editor)))

      # set the editor watcher for the level array file
      pane = atom.workspace.paneForUri tilemapPath
      if pane?
        tileEditor = pane.itemForUri tilemapPath
        if @tileEditor != tileEditor
          if @tileEditor?
            @unsubscribe @tileEditor
          @tileEditor = tileEditor
          if @tileEditor?
            @subscribe @tileEditor, 'cursors-moved', =>
              @renderTileEditorCursor(@tileEditor)


      width  = @canvas[0].width  = @overlay[0].width  = level.width * @TILE_SIZE
      height = @canvas[0].height = @overlay[0].height = level.height * @TILE_SIZE

      ctx = @canvas[0].getContext('2d')
      ctx.fillStyle = 'rgb(0.2, 0, 0.2)'
      ctx.fillRect 0, 0, width, height

      ctx.fillStyle = 'green'
      for y in [0...level.height]
        for x in [0...level.width]
          id = level.content[y][x]
          if tileset?
            if id != -1
              ctx.drawImage tileset, id * 16, 0, 16, 16, x * @TILE_SIZE, y * @TILE_SIZE, @TILE_SIZE, @TILE_SIZE
          else
            if id == 0
              ctx.fillRect x * @TILE_SIZE, y * @TILE_SIZE, @TILE_SIZE, @TILE_SIZE

      if data.Guards?
        for ai in data.Guards
          if ai? and ai.path?
            path = []
            for v in ai.path
              if v?
                path.push v
                if v.p?
                  v.x = (v.p[0] + 0.5) * @TILE_SIZE
                  v.y = (v.p[1] + 0.5) * @TILE_SIZE
                else
                  v.x = 0; v.y = 0

            prevPos = path[0]
            reversed = (ai.direction == 'backward')
            for v in path[1..]
              @drawDirectionalLine ctx, prevPos, v, reversed
              prevPos = v

            if ai.type == 'circular'
              @drawDirectionalLine ctx, prevPos, path[0], reversed

            startPoint = null
            for v in path
              if v.startpoint
                startPoint = v
              ctx.strokeStyle = "yellow"
              if v.stop
                ctx.beginPath()
                ctx.arc v.x, v.y, 5, 0, 2 *Math.PI
                ctx.stroke()

            # Draw start point
            unless startPoint? then startPoint = path[0]
            ctx.strokeStyle = "rgb(0.5, 1, 0.5)"
            ctx.beginPath()
            ctx.rect startPoint.x - 6, startPoint.y - 6, 12, 12
            ctx.stroke()

    if data["tileset"]?
      tileset = new Image()
      tileset.onload = doit
      tileset.src = dir + data["tileset"]
    else doit()

  readLevel: (levelFileName) ->
    try
      levelXML = fs.readFileSync(levelFileName)
    catch e
      return null

    parser = new DOMParser()
    dom = parser.parseFromString(levelXML, "text/xml")
    if dom.documentElement.nodeName == "parsererror"
      console.log "error while parsing"
      return null
    layer = dom.getElementsByTagName('Layer')[0]
    if layer == null
      console.log "no layer xml node!"
      return null
    arr = layer.textContent.split("\n").map((r) ->
      r.split(" ").map((i) -> parseInt i))

    level =
      width: arr[0].length
      height: arr.length
      content: arr

    return level

  getYAMLDoc: (editor)->
    text = editor.getText()
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

  renderCursor: (editor) ->
    ctx = @overlay[0].getContext '2d'
    ctx.clearRect 0, 0, @overlay[0].width, @overlay[0].height
    ctx.strokeStyle = "orange"
    for c in editor.getCursors()
      m = c.getCurrentBufferLine().match(/\[\s*(\d+),\s*(\d+)\s*\]/)
      if m? and m[1]? and m[2]?
        ctx.beginPath()
        ctx.arc (parseInt(m[1]) + 0.5) * @TILE_SIZE, (parseInt(m[2]) + 0.5) * @TILE_SIZE, 2.5, 0, 2 * Math.PI
        ctx.stroke()

  drawDirectionalLine: (ctx, a, b, reversed) ->
    if reversed
      t = a
      a = b
      b = t

    grad= ctx.createLinearGradient(a.x, a.y, b.x, b.y)
    grad.addColorStop(0, "yellow")
    grad.addColorStop(1, "red")
    ctx.strokeStyle = grad
    ctx.beginPath()
    ctx.moveTo(a.x, a.y)
    ctx.lineTo(b.x, b.y)
    ctx.stroke()

  selectWords: ->
    console.log "choose"
    editor = atom.workspace.activePaneItem
    currentRange = editor.getSelectedBufferRange()
    ranges = []
    editor.getBuffer().scanInRange /[^\s]+/g, currentRange, ({range}) ->
      ranges.push range
    editor.setSelectedBufferRanges(ranges)

  renderTileEditorCursor: (editor)->
    # render the cursor in tile editor
    c = editor.getCursor()
    buf = editor.getBuffer()
    curPos = c.getBufferPosition()
    behRange = new Range buf.getFirstPosition(), curPos
    # aftRange = new Range curPos, buf.getEndPosition()

    startRow = null
    buf.backwardsScanInRange /<\/?Layer/, behRange, ({matchText, range})=>
      if matchText == "<Layer"
        startRow = range.getRows()[0]

    ctx = @overlay[0].getContext '2d'
    ctx.clearRect 0, 0, @overlay[0].width, @overlay[0].height
    ctx.strokeStyle = "orange"

    if startRow?
      rN = c.getBufferRow() - startRow
      cN = 0

      lBehRange = new Range new Point(curPos.row, 0), curPos
      buf.scanInRange /\b[+\-\d]+\b\s/g, lBehRange, -> cN += 1

      ctx.strokeRect cN * @TILE_SIZE, rN * @TILE_SIZE, @TILE_SIZE, @TILE_SIZE
