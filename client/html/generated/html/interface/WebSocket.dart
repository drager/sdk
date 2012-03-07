// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// WARNING: Do not edit - generated code.

interface WebSocket extends EventTarget {

  static final int CLOSED = 3;

  static final int CLOSING = 2;

  static final int CONNECTING = 0;

  static final int OPEN = 1;

  final String URL;

  String binaryType;

  final int bufferedAmount;

  final String extensions;

  final String protocol;

  final int readyState;

  final String url;

  WebSocketEvents get on();

  void _addEventListener(String type, EventListener listener, [bool useCapture]);

  void close([int code, String reason]);

  bool _dispatchEvent(Event evt);

  void _removeEventListener(String type, EventListener listener, [bool useCapture]);

  bool send(String data);
}

interface WebSocketEvents extends Events {

  EventListenerList get close();

  EventListenerList get error();

  EventListenerList get message();

  EventListenerList get open();
}