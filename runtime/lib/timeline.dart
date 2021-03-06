// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:_internal';

patch int _getTraceClock() native "Timeline_getTraceClock";

patch int _getNextAsyncId() native "Timeline_getNextAsyncId";

patch int _getIsolateNum() native "Timeline_getIsolateNum";

patch void _reportTaskEvent(
    int start,
    int taskId,
    String phase,
    String category,
    String name,
    String argumentsAsJson) native "Timeline_reportTaskEvent";

patch void _reportCompleteEvent(
    int start,
    int end,
    String category,
    String name,
    String argumentsAsJson) native "Timeline_reportCompleteEvent";
