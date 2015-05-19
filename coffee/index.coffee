# Copyright (c) 2015 mizchi
# Released under the MIT license
# https://raw.githubusercontent.com/mizchi/md2react/master/LICENSE

# ランダム文字列を生成してGUIDとする
myGuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace /[xy]/g, (c) ->
  r = Math.random()*16|0
  v = if c == 'x' then r else (r&0x3|0x8)
  v.toString(16)

defaulMarkdown = '''
# 小見出し1

参照：[Erlangで一旦何か作ってみた](http://dekokun.github.io/posts/2015-05-10.html)

mizchiさんのmd2reactのplaygroundをほぼそのまま使わせて頂いています

## md2react playground

- license: MIT
- author: mizchi
- maintainers: mizchi <miz404@gmail.com>

## 小見出し2

- hogehoge
- fugafuga

1. まず文字を入力する
1. 次に文字を入力する
1. その次に文字を入力する

```javascript
var a = 1;
var b = 2;
```

## 斜体

*abc*

## 太字

**abc**

## 取り消し

<del>abc</del>
'''

global.React = require('react')
md2react = require('md2react')
SocketService = require('./SocketService')

webSocketUrl =
  if (location.hash == '#dev')
    'localhost:8001/websocket'
  else
    'erl-editor.herokuapp.com/websocket'
socketService = new SocketService(webSocketUrl)

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
        markdown = if data.markdown == "" then defaulMarkdown else data.markdown
        @setState
          markdown: markdown,
          # 暫定版キャレット位置維持機能。
          # 触っているところより前が書き換わると維持されないという…
          () =>
            editor.setSelectionRange(caretStart, caretEnd)
         @contentUpdateFromMarkdown markdown
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
      $ 'h1', {
        key: 'headword',
        style: {textAlign: 'center', fontFamily: '"Poiret One", cursive', fontSize: '25px', height: '50px', lineHeight: '50px'}},
        'erlang editor'
      $ 'div', {key: 'layout', className: 'flex'}, [
        $ 'div', {key: 'editorContainer', style:{
          width: '50%', borderRight: '1px solid', borderColor: '#999', overflow: 'hidden'}
        }, [
          $ 'textarea', {
            key: 'editor',
            ref:'editor'
            onChange: @onChangeTextarea
            style: {
              height: '100%',
              width: '100%',
              border: 0,
              outline: 0,
              fontSize: '14px',
              padding: '5px',
              overflow: 'auto',
              fontFamily:'Consolas, Menlo, monospace',
              resize: 'none',
              background: 'transparent'
            }
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
  React.render($(Editor, {}), document.body)
