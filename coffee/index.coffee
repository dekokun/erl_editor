# Copyright (c) 2015 mizchi
# Released under the MIT license
# https://raw.githubusercontent.com/mizchi/md2react/master/LICENSE

SocketService = require('./SocketService')

webSocketUrl =
  if (location.hash == '#dev')
    'localhost:8001/websocket'
  else
    'erl-editor.herokuapp.com/websocket'
myGuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace /[xy]/g, (c) ->
  r = Math.random()*16|0
  v = if c == 'x' then r else (r&0x3|0x8)
  v.toString(16)

socketService = new SocketService(webSocketUrl)

global.React = require('react')
md2react = require('md2react')

$ = React.createElement

Editor = React.createClass
  contentUpdateFromMarkdown: (markdown)->
    @setState
      markdown: markdown
    try
      content = md2react markdown,
        gfm: true
        breaks: true
        tables: true
        # highlight: (code, lang, key) -> # custom highlighter
        #   "#{lang}: #{code}"
      @setState content: content
    catch e
      console.warn 'markdown parse error'

  componentDidMount: ->
    socketService.addMessageHandler (data)=>
      editor = @refs.editor.getDOMNode()
      caretStart = editor.selectionStart
      caretEnd = editor.selectionEnd
      # 自分以外からメッセージが来た場合だけmarkdownを更新する
      if data.from != myGuid
        @setState
          markdown: data.markdown,
          # 暫定版キャレット位置維持機能。
          # 触っているところより前が書き換わると維持されないという…
          () =>
            editor.setSelectionRange(caretStart, caretEnd)
         @contentUpdateFromMarkdown data.markdown
    @syncMarkdownFromServer()

  sendMarkdown: (markdown)->
    socketService.sendRequest(
      set_markdown: markdown
      from: myGuid
    )
  syncMarkdownFromServer: () ->
    socketService.sendRequest(
      'get_markdown'
    )

  getInitialState: ->
    content: null
    markdown: null

  onChangeTextarea: ->
    editor = @refs.editor.getDOMNode()
    @sendMarkdown(editor.value)
    @contentUpdateFromMarkdown(editor.value)

  render: ->
    $ 'div', {key: 'root'}, [
      $ 'h1', {key: 'headword', style: {textAlign: 'center', fontFamily: '"Poiret One", cursive', fontSize: '25px', height: '50px', lineHeight: '50px'}}, 'erlang editor'
      $ 'div', {key: 'layout', className: 'flex'}, [
        $ 'div', {key: 'editorContainer', style:{
          width: '50%', borderRight: '1px solid', borderColor: '#999', overflow: 'hidden'}
        }, [
          $ 'textarea', {
            key: 'editor',
            ref:'editor'
            onChange: @onChangeTextarea
            style: {height: '100%', width: '100%', border: 0, outline: 0, fontSize: '14px', padding: '5px', overflow: 'auto', fontFamily:'Consolas, Menlo, monospace', resize: 'none', background: 'transparent'}
            value: @state.markdown
          }
        ]
        $ 'div',{
          className: 'previewContainer',
          key: 'previewContainer',
          style: {
            width: '50%'
            overflow: 'auto'
            padding: '5px'
            fontFamily: "'Helvetica Neue', Helvetica"
          }
        }, if @state.content then [@state.content] else ''
      ]
    ]

window.addEventListener 'DOMContentLoaded', ->
  React.render(React.createElement(Editor, {}), document.body)
