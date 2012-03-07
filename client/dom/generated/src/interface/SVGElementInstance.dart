// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// WARNING: Do not edit - generated code.

interface SVGElementInstance extends EventTarget {

  final SVGElementInstanceList childNodes;

  final SVGElement correspondingElement;

  final SVGUseElement correspondingUseElement;

  final SVGElementInstance firstChild;

  final SVGElementInstance lastChild;

  final SVGElementInstance nextSibling;

  final SVGElementInstance parentNode;

  final SVGElementInstance previousSibling;

  void addEventListener(String type, EventListener listener, [bool useCapture]);

  bool dispatchEvent(Event event);

  void removeEventListener(String type, EventListener listener, [bool useCapture]);
}