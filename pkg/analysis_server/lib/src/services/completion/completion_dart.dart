// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library analysis_server.src.services.completion.completion_dart;

import 'package:analysis_server/src/provisional/completion/completion_core.dart';
import 'package:analysis_server/src/provisional/completion/completion_dart.dart';
import 'package:analysis_server/src/provisional/completion/dart/completion_target.dart';
import 'package:analysis_server/src/services/completion/completion_core.dart';
import 'package:analyzer/src/generated/ast.dart';

/**
 * The information about a requested list of completions within a Dart file.
 */
class DartCompletionRequestImpl extends CompletionRequestImpl
    implements DartCompletionRequest {
  /**
   * The compilation unit in which the completion was requested.
   */
  final CompilationUnit unit;

  /**
   * A flag indicating whether the compilation [unit] is resolved.
   */
  final bool isResolved;

  /**
   * The completion target.  This determines what part of the parse tree
   * will receive the newly inserted text.
   */
  final CompletionTarget target;

  /**
   * Initialize a newly created completion request based on the given arguments.
   */
  DartCompletionRequestImpl(
      CompletionRequest request, this.unit, this.isResolved, this.target)
      : super(request.context, request.resourceProvider, request.source,
            request.offset);
}
