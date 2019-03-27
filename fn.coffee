###
#    Copyright (c) 2018 Unrud<unrud@outlook.com>
#
#    This file is part of Remote-Touchpad.
#
#    Remote-Touchpad is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    Remote-Touchpad is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with Remote-Touchpad.  If not, see <http://www.gnu.org/licenses/>.
###

# [1 Touch, 2 Touches, 3 Touches]
TOUCH_MOVE_THRESHOLD = [
  10
  15
  15
]
TOUCH_TIMEOUT = 250
DPI = 100000
# [[px/s, mult], ...]
POINTER_ACCELERATION = [
  [
    0
    0
  ]
  [
    87
    1
  ]
  [
    173
    1
  ]
  [
    553
    2
  ]
]
POINTER_BUTTON_LEFT = 0
POINTER_BUTTON_RIGHT = 1
POINTER_BUTTON_MIDDLE = 2
KEY_VOLUME_MUTE = 0
KEY_VOLUME_DOWN = 1
KEY_VOLUME_UP = 2
KEY_MEDIA_PLAY_PAUSE = 3
KEY_MEDIA_PREV_TRACK = 4
KEY_MEDIA_NEXT_TRACK = 5
ws = undefined
pad = undefined
padlabel = undefined
touchMoved = false
touchStart = 0
touchLastEnd = 0
touchReleasedCount = 0
ongoingTouches = []
moveXSum = 0
moveYSum = 0
scrollXSum = 0
scrollYSum = 0
dragging = false
draggingTimeout = null
scrolling = false

fullscreenEnabled = ->
  document.fullscreenEnabled or document.webkitFullscreenEnabled or document.mozFullScreenEnabled or document.msFullscreenEnabled or false

requestFullscreen = (e) ->
  if e.requestFullscreen
    e.requestFullscreen()
  else if e.webkitRequestFullscreen
    e.webkitRequestFullscreen()
  else if e.mozRequestFullScreen
    e.mozRequestFullScreen()
  else if e.msRequestFullscreen
    e.msRequestFullscreen()
  return

exitFullscreen = ->
  if document.exitFullscreen
    document.exitFullscreen()
  else if document.webkitExitFullscreen
    document.webkitExitFullscreen()
  else if document.mozCancelFullScreen
    document.mozCancelFullScreen()
  else if document.msExitFullscreen
    document.msExitFullscreen()
  return

fullscreenElement = ->
  document.fullscreenElement or document.webkitFullscreenElement or document.mozFullScreenElement or document.msFullscreenElement or null

addFullscreenchangeEventListener = (listener) ->
  if document.fullscreenElement != undefined
    document.addEventListener 'fullscreenchange', listener
  else if document.webkitFullscreenElement != undefined
    document.addEventListener 'webkitfullscreenchange', listener
  else if document.mozFullScreenElement != undefined
    document.addEventListener 'mozfullscreenchange', listener
  else if document.msFullscreenElement != undefined
    document.addEventListener 'MSFullscreenChange', listener
  return

copyTouch = (touch, timeStamp) ->
  {
    identifier: touch.identifier
    pageX: touch.pageX
    pageXStart: touch.pageX
    pageY: touch.pageY
    pageYStart: touch.pageY
    timeStamp: timeStamp
  }

ongoingTouchIndexById = (idToFind) ->
  i = 0
  while i < ongoingTouches.length
    id = ongoingTouches[i].identifier
    if id == idToFind
      return i
    i++
  -1

calculatePointerAccelerationMult = (speed) ->
  i = 0
  while i < POINTER_ACCELERATION.length
    s2 = POINTER_ACCELERATION[i][0]
    a2 = POINTER_ACCELERATION[i][1]
    if s2 <= speed
      i++
      continue
    if i == 0
      return a2
    s1 = POINTER_ACCELERATION[i - 1][0]
    a1 = POINTER_ACCELERATION[i - 1][1]
    return (speed - s1) / (s2 - s1) * (a2 - a1) + a1
    i++
  if POINTER_ACCELERATION.length > 0
    return POINTER_ACCELERATION[POINTER_ACCELERATION.length - 1][1]
  1

onDraggingTimeout = (POINTER_BUTTON) ->
  draggingTimeout = null
  ws.send 'b' + POINTER_BUTTON + ';0'
  return

updateMoveAndScroll = ->
  moveX = Math.trunc(moveXSum)
  moveY = Math.trunc(moveYSum)
  if Math.abs(moveX) >= 1 or Math.abs(moveY) >= 1
    moveXSum -= moveX
    moveYSum -= moveY
    ws.send 'm' + moveX + ';' + moveY
  scrollX = Math.trunc(scrollXSum)
  scrollY = Math.trunc(scrollYSum)
  if Math.abs(scrollX) >= 1 or Math.abs(scrollY) >= 1
    scrollXSum -= scrollX
    scrollYSum -= scrollY
    scrolling = true
    ws.send 's' + scrollX + ';' + scrollY
  return

handleStart = (evt) ->
  if ongoingTouches.length == 0
    touchStart = evt.timeStamp
    touchMoved = false
    touchReleasedCount = 0
    dragging = false
  touches = evt.changedTouches
  i = 0
  while i < touches.length
    if touches[i].target != pad and touches[i].target != padlabel
      i++
      continue
    evt.preventDefault()
    ongoingTouches.push copyTouch(touches[i], evt.timeStamp)
    touchLastEnd = 0
    if !dragging
      moveXSum = Math.trunc(moveXSum)
      moveYSum = Math.trunc(moveYSum)
    scrollXSum = Math.trunc(scrollXSum)
    scrollYSum = Math.trunc(scrollYSum)
    if draggingTimeout != null
      clearTimeout draggingTimeout
      draggingTimeout = null
      dragging = true
    if scrolling
      ws.send 'sf'
      scrolling = false
    i++
  return

handleEnd = (evt) ->
  touches = evt.changedTouches
  i = 0
  while i < touches.length
    idx = ongoingTouchIndexById(touches[i].identifier)
    if idx < 0
      i++
      continue
    ongoingTouches.splice idx, 1
    touchReleasedCount++
    touchLastEnd = evt.timeStamp
    if scrolling
      ws.send 'sf'
      scrolling = false
    i++
  if touchReleasedCount > TOUCH_MOVE_THRESHOLD.length
    touchMoved = true
  if ongoingTouches.length == 0 and touchReleasedCount >= 1 and dragging
    # ws.send 'b' + POINTER_BUTTON_LEFT + ';0'
    button = 0
    if touchReleasedCount == 1
      button = POINTER_BUTTON_LEFT
    else if touchReleasedCount == 2
      button = POINTER_BUTTON_RIGHT
    else if touchReleasedCount == 3
      button = POINTER_BUTTON_MIDDLE
    ws.send 'b' + button + ';0'
  if ongoingTouches.length == 0 and touchReleasedCount >= 1 and !touchMoved and evt.timeStamp - touchStart < TOUCH_TIMEOUT
    button = 0
    if touchReleasedCount == 1
      button = POINTER_BUTTON_LEFT
    else if touchReleasedCount == 2
      button = POINTER_BUTTON_RIGHT
    else if touchReleasedCount == 3
      button = POINTER_BUTTON_MIDDLE
    ws.send 'b' + button + ';1'
    if button in [POINTER_BUTTON_LEFT, POINTER_BUTTON_RIGHT]
      draggingTimeout = setTimeout(
        -> onDraggingTimeout button
        TOUCH_TIMEOUT
      )
    else
      ws.send 'b' + button + ';0'
  return

handleCancel = (evt) ->
  touches = evt.changedTouches
  i = 0
  while i < touches.length
    idx = ongoingTouchIndexById(touches[i].identifier)
    if idx < 0
      i++
      continue
    ongoingTouches.splice idx, 1
    touchReleasedCount++
    touchLastEnd = evt.timeStamp
    touchMoved = true
    if scrolling
      ws.send 'sf'
      scrolling = false
    i++
  return

handleMove = (evt) ->
  sumX = 0
  sumY = 0
  touches = evt.changedTouches
  i = 0
  while i < touches.length
    idx = ongoingTouchIndexById(touches[i].identifier)
    if idx < 0
      i++
      continue
    if !touchMoved
      dist = Math.sqrt((touches[i].pageX - (ongoingTouches[idx].pageXStart)) ** 2 + (touches[i].pageY - (ongoingTouches[idx].pageYStart)) ** 2)
      if ongoingTouches.length > TOUCH_MOVE_THRESHOLD.length or dist > TOUCH_MOVE_THRESHOLD[ongoingTouches.length - 1] or evt.timeStamp - touchStart >= TOUCH_TIMEOUT
        touchMoved = true
    dx = touches[i].pageX - (ongoingTouches[idx].pageX)
    dy = touches[i].pageY - (ongoingTouches[idx].pageY)
    timeDelta = evt.timeStamp - (ongoingTouches[idx].timeStamp)
    sumX += dx * calculatePointerAccelerationMult(Math.abs(dx) / timeDelta * DPI)
    sumY += dy * calculatePointerAccelerationMult(Math.abs(dy) / timeDelta * DPI)
    ongoingTouches[idx].pageX = touches[i].pageX
    ongoingTouches[idx].pageY = touches[i].pageY
    ongoingTouches[idx].timeStamp = evt.timeStamp
    i++
  if touchMoved and evt.timeStamp - touchLastEnd >= TOUCH_TIMEOUT
    if ongoingTouches.length == 1 or dragging
      moveXSum += sumX
      moveYSum += sumY
    else if ongoingTouches.length == 2
      scrollXSum -= sumX
      scrollYSum -= sumY
    updateMoveAndScroll()
  return

challengeResponse = (message) ->
  shaObj = new jsSHA('SHA-256', 'TEXT')
  shaObj.setHMACKey message, 'TEXT'
  shaObj.update window.location.hash.substr(1)
  btoa shaObj.getHMAC('BYTES')

window.addEventListener 'load', (->
  authenticated = false
  opening = document.getElementById('opening')
  closed = document.getElementById('closed')

  showScene = (scene) ->
    [
      opening
      closed
      pad
      keys
      keyboard
    ].forEach (e) ->
      e.style.display = if e == scene then 'flex' else 'none'
      return
    return

  showKeys = ->
    exitFullscreen()
    showScene keys
    if history.state != 'keys'
      history.pushState 'keys', ''
    return

  showKeyboard = ->
    exitFullscreen()
    showScene keyboard
    text.focus()
    if history.state != 'keyboard'
      history.pushState 'keyboard', ''
    return

  pad = document.getElementById('pad')
  padlabel = document.getElementById('padlabel')
  keys = document.getElementById('keys')
  keyboard = document.getElementById('keyboard')
  fullscreenbutton = document.getElementById('fullscreenbutton')
  text = document.getElementById('text')
  text.value = ''
  showScene opening
  wsProtocol = 'wss:'
  if location.protocol == 'http:'
    wsProtocol = 'ws:'
  ws = new WebSocket(wsProtocol + '//' + location.hostname + (if location.port then ':' + location.port else '') + '/ws')

  ws.onmessage = (event) ->
    if authenticated
      ws.close()
      return
    authenticated = true
    ws.send challengeResponse(event.data)
    if history.state == 'keyboard'
      showKeyboard()
    else if history.state == 'keys'
      showKeys()
    else
      showScene pad
    return

  ws.onclose = ->
    exitFullscreen()
    showScene closed
    return

  if !fullscreenEnabled()
    fullscreenbutton.style.display = 'none'
  fullscreenbutton.addEventListener 'click', ->
    if fullscreenElement()
      exitFullscreen()
    else
      requestFullscreen pad
    return
  requestFullscreen pad
  [
    {
      id: 'prevtrackbutton'
      key: KEY_MEDIA_PREV_TRACK
    }
    {
      id: 'playpausebutton'
      key: KEY_MEDIA_PLAY_PAUSE
    }
    {
      id: 'nexttrackbutton'
      key: KEY_MEDIA_NEXT_TRACK
    }
    {
      id: 'volumedownbutton'
      key: KEY_VOLUME_DOWN
    }
    {
      id: 'volumemutebutton'
      key: KEY_VOLUME_MUTE
    }
    {
      id: 'volumeupbutton'
      key: KEY_VOLUME_UP
    }
  ].forEach (o) ->
    document.getElementById(o.id).addEventListener 'click', ->
      ws.send 'k' + o.key
      return
    return
  document.getElementById('sendbutton').addEventListener 'click', ->
    if text.value != ''
      ws.send 't' + text.value
      text.value = ''
    window.history.back()
    return

  window.onpopstate = ->
    if pad.style.display != 'none' or keyboard.style.display != 'none' or keys.style.display != 'none'
      if history.state == 'keys'
        showKeys()
      else if history.state == 'keyboard'
        showKeyboard()
      else
        showScene pad
    return

  document.getElementById('reloadbutton').addEventListener 'click', ->
    location.reload()
    return
  pad.addEventListener 'touchstart', handleStart, false
  pad.addEventListener 'touchend', handleEnd, false
  pad.addEventListener 'touchcancel', handleCancel, false
  pad.addEventListener 'touchmove', handleMove, false
  return
), false
