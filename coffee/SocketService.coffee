SocketService = (url)->
  service = {}
  pendingCallbacks = {}
  messageHandlers = []
  currentMessageId = 0
  ws = undefined
  preConnectionRequests = []
  connected = false
  url = url || window.location.hostname + (if location.port then ':' + location.port else '')

  init = ->
    service = {}
    pendingCallbacks = {}
    # messageHandlerは接続が切れようがなにしようがそのままにしていたいのでinitでは初期化しない
    currentMessageId = 0
    preConnectionRequests = []
    connected = false
    ws_url = 'ws://' + url
    ws = new WebSocket(ws_url)

    ws.onopen = ->
      connected = true
      if preConnectionRequests.length == 0
        return
      console.log 'Sending (%d) requests', preConnectionRequests.length
      i = 0
      c = preConnectionRequests.length
      while i < c
        ws.send JSON.stringify(preConnectionRequests[i])
        i++
      preConnectionRequests = []

    ws.onclose = ->
      connected = false

    ws.onmessage = (message) ->
      listener JSON.parse(message.data)

  addMessageHandler = (handler) ->
    unless typeof handler == 'function'
      throw new Error('handler must be function')
    messageHandlers.push handler

  sendRequest = (request, cb = null) ->
    # websocket closing / closed, reconnect
    if ws and ~[
        2
        3
      ].indexOf(ws.readyState)
      connected = false
      init()
    if (cb)
      request.$id = generateMessageId()
      pendingCallbacks[request.$id] = cb

    if !connected
      #console.log('Not connected yet, saving request', request);
      preConnectionRequests.push request
    else
      #console.log('Sending request', request);
      ws.send JSON.stringify(request)
    request.$id

  listener = (message) ->
    #console.log('listener, id:', message.$id, 'ws.readyState', ws.readyState);
    # If an object exists with id in our pendingCallbacks object, resolve it
    if pendingCallbacks.hasOwnProperty(message.$id)
      pendingCallbacks[message.$id] message
    handler(message) for handler in messageHandlers

  requestComplete = (id) ->
    #console.log("requestComplete:", id, 'ws.readyState', ws.readyState);
    delete pendingCallbacks[id]

  stopRequest = (id) ->
    ws.close()
    init()

  generateMessageId = ->
    if currentMessageId > 10000
      currentMessageId = 0
    (new Date).getTime().toString() + '~' + (++currentMessageId).toString()

  init()
  service.sendRequest = sendRequest
  service.requestComplete = requestComplete
  service.stopRequest = stopRequest
  service.addMessageHandler = addMessageHandler
  service

module.exports = SocketService
