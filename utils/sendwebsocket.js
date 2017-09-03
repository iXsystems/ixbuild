var WebSocket = require('ws');
var wsserver = process.argv[2];
var stdargs = "";
var ignorefirst = "false";
var nstatus = "connect";

function connectWebSocket()
{
  websocket = new WebSocket(wsserver);
  websocket.onopen = function(evt) { onOpen(evt) };
  websocket.onclose = function(evt) { onClose(evt) };
  websocket.onmessage = function(evt) { onMessage(evt) };
  websocket.onerror = function(evt) { onError(evt) };
}

function onOpen(evt)
{
  var connectjson = '{ "msg":"connect", "version":"1", "support": ["1"] }';
  wstatus = "idle";
  doSend(connectjson);
//  doSend(authjson);
//  doSend(stdargs);
}

function onClose(evt)
{
}

function onError(evt)
{
  console.log(evt);
}

function onMessage(evt)
{
  var authjson = '{ "id": "foologin", "msg":"method", "method":"auth.login", "params": [ "' + process.argv[3] + '", "' + process.argv[4] + '" ] }';

  var jsonobj = JSON.parse(evt.data);
  console.log(JSON.stringify(jsonobj, null, 2));
  if ( nstatus == "connect" ) {
    nstatus = "auth";
    doSend(authjson);
    return;
  }
  if ( nstatus == "auth" ) {
    nstatus = "connected";
    doSend(stdargs);
    return;
  }
  if ( nstatus == "connected" ) {
    websocket.close();
  }
}

function doSend(message)
{
  console.log('Sent: ' + message);
  websocket.send(message);
}

function readStdIn(msg)
{
  stdargs = msg;
}

process.stdin.resume();
process.stdin.setEncoding('utf8');

process.stdin.on('data', function(message) {
  readStdIn(message);
});

connectWebSocket();
