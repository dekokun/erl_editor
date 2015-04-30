# Copyright (c) 2015 mizchi
# Released under the MIT license
# https://raw.githubusercontent.com/mizchi/md2react/master/LICENSE

SocketService = require('./SocketService')

socketService = new SocketService('erl-editor.herokuapp.com//websocket')

global.React = require('react')
md2react = require('md2react')

$ = React.createElement

defaultMarkdown = '''
# Hello
body
1. 1
2. 2
------
- [ ] unchecked
- [x] checked
- foo
`a`
------
```
bbb
```
**AA**
*BB*
[foo](/foo)
![image](http://placehold.it/20x20/27709b/ffffff)
> aaa
> bbb
|  TH  |  TH  |
| ---- | ---- |
|  TD  |  TD  |
|  TD  |  TD  |
'''

defaultMarkdown = '''
```js
var x = 3;
```
'''

Editor = React.createClass
  contentUpdateFromMarkdown: ->
    editor = @refs.editor.getDOMNode()
    @sendMarkdown(editor.value)
    @setState
      markdown: editor.value
    try
      content = md2react editor.value,
        gfm: true
        breaks: true
        tables: true
        # highlight: (code, lang, key) -> # custom highlighter
        #   "#{lang}: #{code}"
      @setState content: content
    catch e
      console.warn 'markdown parse error'

  componentDidMount: ->
    @syncMarkdownFromServer()
    setInterval(
      ()=>
        @syncMarkdownFromServer()
      1000
    )

  sendMarkdown: (markdown)->
    socketService.sendRequest(
      {set_markdown: markdown},
      () => {}
    )
  syncMarkdownFromServer: () ->
    socketService.sendRequest(
      'get_markdown',
      (data) =>
        editor = @refs.editor.getDOMNode()
        caretStart = editor.selectionStart
        caretEnd = editor.selectionEnd
        @setState
          markdown: data.markdown,
            # 雰囲気キャレット維持。触っているところより前が書き換わると維持されないという…
            () =>
              console.log caretStart
              editor.setSelectionRange(caretStart, caretEnd)
         @contentUpdateFromMarkdown
    )

  getInitialState: ->
    content: null
    markdown: null

  render: ->
    $ 'div', {key: 'root'}, [
      $ 'h1', {style: {textAlign: 'center', fontFamily: '"Poiret One", cursive', fontSize: '25px', height: '50px', lineHeight: '50px'}}, 'erlang editor'
      $ 'div', {key: 'layout', className: 'flex'}, [
        $ 'div', {key: 'editorContainer', style:{
          width: '50%', borderRight: '1px solid', borderColor: '#999', overflow: 'hidden'}
        }, [
          $ 'textarea', {
            ref:'editor'
            onChange: @contentUpdateFromMarkdown
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
