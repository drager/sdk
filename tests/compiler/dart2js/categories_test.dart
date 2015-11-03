// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import "memory_compiler.dart";
import "package:expect/expect.dart";
import 'package:async_helper/async_helper.dart';


runTest(String source, String categories, int expectedErrors) async {
  var collector = new DiagnosticCollector();
  CompilationResult result = await runCompiler(
      memorySourceFiles: {"main.dart": source},
      options: ["--categories=$categories"],
      diagnosticHandler: collector);
  print("$source $categories");
  print(collector.errors);
  Expect.equals(expectedErrors, collector.errors.length);
  Expect.equals(0, collector.warnings.length);
}



void main() {
  asyncTest(() async {
    await runTest("import 'dart:async'; main() {}", "Client", 0);
    await runTest("import 'dart:async'; main() {}", "Server", 0);
    await runTest("import 'dart:html'; main() {}", "Client", 0);
    await runTest("import 'dart:html'; main() {}", "Server", 1);
    await runTest("import 'dart:io'; main() {}", "Client", 28);
    await runTest("import 'dart:io'; main() {}", "Server", 0);
    await runTest("import 'dart:_internal'; main() {}", "Client", 1);
    await runTest("import 'dart:_internal'; main() {}", "Server", 1);
  });
}
