// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// WARNING: Do not edit - generated code.

interface EventSource extends EventTarget default _EventSourceFactoryProvider {

  EventSource(String scriptUrl);

  static final int CLOSED = 2;

  static final int CONNECTING = 0;

  static final int OPEN = 1;

  final String URL;

  final int readyState;

  final String url;

  void addEventListener(String type, EventListener listener, [bool useCapture]);

  void close();

  bool dispatchEvent(Event evt);

  void removeEventListener(String type, EventListener listener, [bool useCapture]);
}