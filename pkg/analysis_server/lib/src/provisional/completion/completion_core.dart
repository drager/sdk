// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library analysis_server.src.provisional.completion.completion_core;

import 'package:analysis_server/plugin/protocol/protocol.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/source.dart';

/**
 * An object used to produce completions for a specific error. Completion
 * contributors are long-lived objects and must not retain any state between
 * invocations of [computeSuggestions].
 *
 * Clients may implement this class when implementing plugins.
 */
abstract class CompletionContributor {
  /**
   * Compute a list of completion suggestions based on the given completion
   * [request]. Return the suggestions that were computed.
   */
  List<CompletionSuggestion> computeSuggestions(CompletionRequest request);
}

/**
 * The information about a requested list of completions.
 *
 * Clients may not extend, implement or mix-in this class.
 */
abstract class CompletionRequest {
  /**
   * Return the analysis context in which the completion is being requested.
   */
  AnalysisContext get context;

  /**
   * Return the offset within the source at which the completion is being
   * requested.
   */
  int get offset;

  /**
   * Return the resource provider associated with this request.
   */
  ResourceProvider get resourceProvider;

  /**
   * Return the source in which the completion is being requested.
   */
  Source get source;
}

/**
 * The result of computing suggestions for code completion.
 *
 * Clients may implement this class when implementing plugins.
 */
abstract class CompletionResult {
  /**
   * Return the length of the text to be replaced. This will be zero (0) if the
   * suggestion is to be inserted, otherwise it will be greater than zero. For
   * example, if the remainder of the identifier containing the cursor is to be
   * replaced when the suggestion is applied, in which case the length will be
   * the number of characters in the existing identifier.
   */
  int get replacementLength;

  /**
   * Return the offset of the start of the text to be replaced. This will be
   * different than the offset used to request the completion suggestions if
   * there was a portion of text that needs to be replaced. For example, if a
   * partial identifier is immediately before the original offset, in which case
   * the replacementOffset will be the offset of the beginning of the
   * identifier.
   */
  int get replacementOffset;

  /**
   * Return the list of suggestions being contributed by the contributor.
   */
  List<CompletionSuggestion> get suggestions;
}
