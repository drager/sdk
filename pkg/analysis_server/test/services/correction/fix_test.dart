// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.services.correction.fix;

import 'package:analysis_server/plugin/edit/fix/fix_core.dart';
import 'package:analysis_server/plugin/protocol/protocol.dart'
    hide AnalysisError;
import 'package:analysis_server/src/services/correction/fix.dart';
import 'package:analysis_server/src/services/correction/fix_internal.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/source/package_map_resolver.dart';
import 'package:analyzer/src/generated/error.dart';
import 'package:analyzer/src/generated/parser.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:unittest/unittest.dart';

import '../../abstract_context.dart';
import '../../abstract_single_unit.dart';
import '../../utils.dart';

main() {
  initializeTestEnvironment();
  defineReflectiveTests(FixProcessorTest);
}

typedef bool AnalysisErrorFilter(AnalysisError error);

@reflectiveTest
class FixProcessorTest extends AbstractSingleUnitTest {
  AnalysisErrorFilter errorFilter = (AnalysisError error) {
    return error.errorCode != HintCode.UNUSED_CATCH_CLAUSE &&
        error.errorCode != HintCode.UNUSED_CATCH_STACK &&
        error.errorCode != HintCode.UNUSED_ELEMENT &&
        error.errorCode != HintCode.UNUSED_FIELD &&
        error.errorCode != HintCode.UNUSED_LOCAL_VARIABLE;
  };

  Fix fix;
  SourceChange change;
  String resultCode;

  void assert_undefinedFunction_create_returnType_bool(String lineWithTest) {
    resolveTestUnit('''
main() {
  bool b = true;
  $lineWithTest
}
''');
    assertHasFix(
        DartFixKind.CREATE_FUNCTION,
        '''
main() {
  bool b = true;
  $lineWithTest
}

bool test() {
}
''');
  }

  void assertHasFix(FixKind kind, String expected) {
    AnalysisError error = _findErrorToFix();
    fix = _assertHasFix(kind, error);
    change = fix.change;
    // apply to "file"
    List<SourceFileEdit> fileEdits = change.edits;
    expect(fileEdits, hasLength(1));
    resultCode = SourceEdit.applySequence(testCode, change.edits[0].edits);
    // verify
    expect(resultCode, expected);
  }

  void assertNoFix(FixKind kind) {
    AnalysisError error = _findErrorToFix();
    List<Fix> fixes = _computeFixes(error);
    for (Fix fix in fixes) {
      if (fix.kind == kind) {
        throw fail('Unexpected fix $kind in\n${fixes.join('\n')}');
      }
    }
  }

  Position expectedPosition(String search) {
    int offset = resultCode.indexOf(search);
    return new Position(testFile, offset);
  }

  List<Position> expectedPositions(List<String> patterns) {
    List<Position> positions = <Position>[];
    patterns.forEach((String search) {
      positions.add(expectedPosition(search));
    });
    return positions;
  }

  List<LinkedEditSuggestion> expectedSuggestions(
      LinkedEditSuggestionKind kind, List<String> values) {
    return values.map((value) {
      return new LinkedEditSuggestion(value, kind);
    }).toList();
  }

  void setUp() {
    super.setUp();
    verifyNoTestUnitErrors = false;
  }

  void test_addFieldFormalParameters_hasRequiredParameter() {
    resolveTestUnit('''
class Test {
  final int a;
  final int b;
  final int c;
  Test(this.a);
}
''');
    assertHasFix(
        DartFixKind.ADD_FIELD_FORMAL_PARAMETERS,
        '''
class Test {
  final int a;
  final int b;
  final int c;
  Test(this.a, this.b, this.c);
}
''');
  }

  void test_addFieldFormalParameters_noParameters() {
    resolveTestUnit('''
class Test {
  final int a;
  final int b;
  final int c;
  Test();
}
''');
    assertHasFix(
        DartFixKind.ADD_FIELD_FORMAL_PARAMETERS,
        '''
class Test {
  final int a;
  final int b;
  final int c;
  Test(this.a, this.b, this.c);
}
''');
  }

  void test_addFieldFormalParameters_noRequiredParameter() {
    resolveTestUnit('''
class Test {
  final int a;
  final int b;
  final int c;
  Test([this.c]);
}
''');
    assertHasFix(
        DartFixKind.ADD_FIELD_FORMAL_PARAMETERS,
        '''
class Test {
  final int a;
  final int b;
  final int c;
  Test(this.a, this.b, [this.c]);
}
''');
  }

  void test_addMissingParameter_function_positional_hasZero() {
    resolveTestUnit('''
test() {}
main() {
  test(1);
}
''');
    assertHasFix(
        DartFixKind.ADD_MISSING_PARAMETER_POSITIONAL,
        '''
test([int i]) {}
main() {
  test(1);
}
''');
  }

  void test_addMissingParameter_function_required_hasOne() {
    resolveTestUnit('''
test(int a) {}
main() {
  test(1, 2.0);
}
''');
    assertHasFix(
        DartFixKind.ADD_MISSING_PARAMETER_REQUIRED,
        '''
test(int a, double d) {}
main() {
  test(1, 2.0);
}
''');
  }

  void test_addMissingParameter_function_required_hasZero() {
    resolveTestUnit('''
test() {}
main() {
  test(1);
}
''');
    assertHasFix(
        DartFixKind.ADD_MISSING_PARAMETER_REQUIRED,
        '''
test(int i) {}
main() {
  test(1);
}
''');
  }

  void test_addMissingParameter_method_positional_hasOne() {
    resolveTestUnit('''
class A {
  test(int a) {}
  main() {
    test(1, 2.0);
  }
}
''');
    assertHasFix(
        DartFixKind.ADD_MISSING_PARAMETER_POSITIONAL,
        '''
class A {
  test(int a, [double d]) {}
  main() {
    test(1, 2.0);
  }
}
''');
  }

  void test_addMissingParameter_method_required_hasOne() {
    resolveTestUnit('''
class A {
  test(int a) {}
  main() {
    test(1, 2.0);
  }
}
''');
    assertHasFix(
        DartFixKind.ADD_MISSING_PARAMETER_REQUIRED,
        '''
class A {
  test(int a, double d) {}
  main() {
    test(1, 2.0);
  }
}
''');
  }

  void test_addMissingParameter_method_required_hasZero() {
    resolveTestUnit('''
class A {
  test() {}
  main() {
    test(1);
  }
}
''');
    assertHasFix(
        DartFixKind.ADD_MISSING_PARAMETER_REQUIRED,
        '''
class A {
  test(int i) {}
  main() {
    test(1);
  }
}
''');
  }

  void test_addPartOfDirective() {
    String partCode = r'''
// Comment first.
// Comment second.

class A {}
''';
    addSource('/part.dart', partCode);
    resolveTestUnit('''
library my.lib;
part 'part.dart';
''');
    _performAnalysis();
    AnalysisError error = _findErrorToFix();
    fix = _assertHasFix(DartFixKind.ADD_PART_OF, error);
    change = fix.change;
    // apply to "file"
    List<SourceFileEdit> fileEdits = change.edits;
    expect(fileEdits, hasLength(1));
    SourceFileEdit fileEdit = change.edits[0];
    expect(fileEdit.file, '/part.dart');
    expect(
        SourceEdit.applySequence(partCode, fileEdit.edits),
        r'''
// Comment first.
// Comment second.

part of my.lib;

class A {}
''');
  }

  void test_addSync_BAD_nullFunctionBody() {
    resolveTestUnit('''
var F = await;
''');
    assertNoFix(DartFixKind.ADD_ASYNC);
  }

  void test_addSync_blockFunctionBody() {
    resolveTestUnit('''
foo() {}
main() {
  await foo();
}
''');
    List<AnalysisError> errors = context.computeErrors(testSource);
    expect(errors, hasLength(2));
    // ParserError: Expected to find ';'
    {
      AnalysisError error = errors[0];
      expect(error.message, "Expected to find ';'");
      List<Fix> fixes = _computeFixes(error);
      expect(fixes, isEmpty);
    }
    // Undefined name 'await'
    {
      AnalysisError error = errors[1];
      expect(error.message, "Undefined name 'await'");
      List<Fix> fixes = _computeFixes(error);
      // has exactly one fix
      expect(fixes, hasLength(1));
      Fix fix = fixes[0];
      expect(fix.kind, DartFixKind.ADD_ASYNC);
      // apply to "file"
      List<SourceFileEdit> fileEdits = fix.change.edits;
      expect(fileEdits, hasLength(1));
      resultCode = SourceEdit.applySequence(testCode, fileEdits[0].edits);
      // verify
      expect(
          resultCode,
          '''
foo() {}
main() async {
  await foo();
}
''');
    }
  }

  void test_addSync_expressionFunctionBody() {
    errorFilter = (AnalysisError error) {
      return error.errorCode == StaticWarningCode.UNDEFINED_IDENTIFIER;
    };
    resolveTestUnit('''
foo() {}
main() => await foo();
''');
    assertHasFix(
        DartFixKind.ADD_ASYNC,
        '''
foo() {}
main() async => await foo();
''');
  }

  void test_boolean() {
    resolveTestUnit('''
main() {
  boolean v;
}
''');
    assertHasFix(
        DartFixKind.REPLACE_BOOLEAN_WITH_BOOL,
        '''
main() {
  bool v;
}
''');
  }

  void test_canBeNullAfterNullAware_chain() {
    resolveTestUnit('''
main(x) {
  x?.a.b.c;
}
''');
    assertHasFix(
        DartFixKind.REPLACE_WITH_NULL_AWARE,
        '''
main(x) {
  x?.a?.b?.c;
}
''');
  }

  void test_canBeNullAfterNullAware_methodInvocation() {
    resolveTestUnit('''
main(x) {
  x?.a.b();
}
''');
    assertHasFix(
        DartFixKind.REPLACE_WITH_NULL_AWARE,
        '''
main(x) {
  x?.a?.b();
}
''');
  }

  void test_canBeNullAfterNullAware_propertyAccess() {
    resolveTestUnit('''
main(x) {
  x?.a().b;
}
''');
    assertHasFix(
        DartFixKind.REPLACE_WITH_NULL_AWARE,
        '''
main(x) {
  x?.a()?.b;
}
''');
  }

  void test_changeToStaticAccess_method() {
    resolveTestUnit('''
class A {
  static foo() {}
}
main(A a) {
  a.foo();
}
''');
    assertHasFix(
        DartFixKind.CHANGE_TO_STATIC_ACCESS,
        '''
class A {
  static foo() {}
}
main(A a) {
  A.foo();
}
''');
  }

  void test_changeToStaticAccess_method_importType() {
    addSource(
        '/libA.dart',
        r'''
library libA;
class A {
  static foo() {}
}
''');
    addSource(
        '/libB.dart',
        r'''
library libB;
import 'libA.dart';
class B extends A {}
''');
    resolveTestUnit('''
import 'libB.dart';
main(B b) {
  b.foo();
}
''');
    assertHasFix(
        DartFixKind.CHANGE_TO_STATIC_ACCESS,
        '''
import 'libB.dart';
import 'libA.dart';
main(B b) {
  A.foo();
}
''');
  }

  void test_changeToStaticAccess_method_prefixLibrary() {
    resolveTestUnit('''
import 'dart:async' as pref;
main(pref.Future f) {
  f.wait([]);
}
''');
    assertHasFix(
        DartFixKind.CHANGE_TO_STATIC_ACCESS,
        '''
import 'dart:async' as pref;
main(pref.Future f) {
  pref.Future.wait([]);
}
''');
  }

  void test_changeToStaticAccess_property() {
    resolveTestUnit('''
class A {
  static get foo => 42;
}
main(A a) {
  a.foo;
}
''');
    assertHasFix(
        DartFixKind.CHANGE_TO_STATIC_ACCESS,
        '''
class A {
  static get foo => 42;
}
main(A a) {
  A.foo;
}
''');
  }

  void test_changeToStaticAccess_property_importType() {
    addSource(
        '/libA.dart',
        r'''
library libA;
class A {
  static get foo => null;
}
''');
    addSource(
        '/libB.dart',
        r'''
library libB;
import 'libA.dart';
class B extends A {}
''');
    resolveTestUnit('''
import 'libB.dart';
main(B b) {
  b.foo;
}
''');
    assertHasFix(
        DartFixKind.CHANGE_TO_STATIC_ACCESS,
        '''
import 'libB.dart';
import 'libA.dart';
main(B b) {
  A.foo;
}
''');
  }

  void test_createClass() {
    resolveTestUnit('''
main() {
  Test v = null;
}
''');
    assertHasFix(
        DartFixKind.CREATE_CLASS,
        '''
main() {
  Test v = null;
}

class Test {
}
''');
    _assertLinkedGroup(change.linkedEditGroups[0], ['Test v =', 'Test {']);
  }

  void test_createClass_BAD_hasUnresolvedPrefix() {
    resolveTestUnit('''
main() {
  prefix.Test v = null;
}
''');
    assertNoFix(DartFixKind.CREATE_CLASS);
  }

  void test_createClass_inLibraryOfPrefix() {
    String libCode = r'''
library my.lib;

class A {}
''';
    addSource('/lib.dart', libCode);
    resolveTestUnit('''
import 'lib.dart' as lib;

main() {
  lib.A a = null;
  lib.Test t = null;
}
''');
    AnalysisError error = _findErrorToFix();
    fix = _assertHasFix(DartFixKind.CREATE_CLASS, error);
    change = fix.change;
    // apply to "lib.dart"
    List<SourceFileEdit> fileEdits = change.edits;
    expect(fileEdits, hasLength(1));
    SourceFileEdit fileEdit = change.edits[0];
    expect(fileEdit.file, '/lib.dart');
    expect(
        SourceEdit.applySequence(libCode, fileEdit.edits),
        r'''
library my.lib;

class A {}

class Test {
}
''');
    expect(change.linkedEditGroups, isEmpty);
  }

  void test_createClass_innerLocalFunction() {
    resolveTestUnit('''
f() {
  g() {
    Test v = null;
  }
}
''');
    assertHasFix(
        DartFixKind.CREATE_CLASS,
        '''
f() {
  g() {
    Test v = null;
  }
}

class Test {
}
''');
    _assertLinkedGroup(change.linkedEditGroups[0], ['Test v =', 'Test {']);
  }

  void test_createClass_itemOfList() {
    resolveTestUnit('''
main() {
  var a = [Test];
}
''');
    assertHasFix(
        DartFixKind.CREATE_CLASS,
        '''
main() {
  var a = [Test];
}

class Test {
}
''');
    _assertLinkedGroup(change.linkedEditGroups[0], ['Test];', 'Test {']);
  }

  void test_createClass_itemOfList_inAnnotation() {
    errorFilter = (AnalysisError error) {
      return error.errorCode == StaticWarningCode.UNDEFINED_IDENTIFIER;
    };
    resolveTestUnit('''
class MyAnnotation {
  const MyAnnotation(a, b);
}
@MyAnnotation(int, const [Test])
main() {}
''');
    assertHasFix(
        DartFixKind.CREATE_CLASS,
        '''
class MyAnnotation {
  const MyAnnotation(a, b);
}
@MyAnnotation(int, const [Test])
main() {}

class Test {
}
''');
    _assertLinkedGroup(change.linkedEditGroups[0], ['Test])', 'Test {']);
  }

  void test_createConstructor_forFinalFields() {
    errorFilter = (AnalysisError error) {
      return error.message.contains("'a'");
    };
    resolveTestUnit('''
class Test {
  final int a;
  final int b = 2;
  final int c;
}
''');
    assertHasFix(
        DartFixKind.CREATE_CONSTRUCTOR_FOR_FINAL_FIELDS,
        '''
class Test {
  final int a;
  final int b = 2;
  final int c;

  Test(this.a, this.c);
}
''');
  }

  void test_createConstructor_insteadOfSyntheticDefault() {
    resolveTestUnit('''
class A {
  int field;

  method() {}
}
main() {
  new A(1, 2.0);
}
''');
    assertHasFix(
        DartFixKind.CREATE_CONSTRUCTOR,
        '''
class A {
  int field;

  A(int i, double d) {
  }

  method() {}
}
main() {
  new A(1, 2.0);
}
''');
  }

  void test_createConstructor_named() {
    resolveTestUnit('''
class A {
  method() {}
}
main() {
  new A.named(1, 2.0);
}
''');
    assertHasFix(
        DartFixKind.CREATE_CONSTRUCTOR,
        '''
class A {
  A.named(int i, double d) {
  }

  method() {}
}
main() {
  new A.named(1, 2.0);
}
''');
    _assertLinkedGroup(change.linkedEditGroups[0], ['named(int ', 'named(1']);
  }

  void test_createConstructorForFinalFields_inTopLevelMethod() {
    resolveTestUnit('''
main() {
  final int v;
}
''');
    assertNoFix(DartFixKind.CREATE_CONSTRUCTOR_FOR_FINAL_FIELDS);
  }

  void test_createConstructorForFinalFields_topLevelField() {
    resolveTestUnit('''
final int v;
''');
    assertNoFix(DartFixKind.CREATE_CONSTRUCTOR_FOR_FINAL_FIELDS);
  }

  void test_createConstructorSuperExplicit() {
    resolveTestUnit('''
class A {
  A(bool p1, int p2, double p3, String p4, {p5});
}
class B extends A {
  B() {}
}
''');
    assertHasFix(
        DartFixKind.ADD_SUPER_CONSTRUCTOR_INVOCATION,
        '''
class A {
  A(bool p1, int p2, double p3, String p4, {p5});
}
class B extends A {
  B() : super(false, 0, 0.0, '') {}
}
''');
  }

  void test_createConstructorSuperExplicit_hasInitializers() {
    resolveTestUnit('''
class A {
  A(int p);
}
class B extends A {
  int field;
  B() : field = 42 {}
}
''');
    assertHasFix(
        DartFixKind.ADD_SUPER_CONSTRUCTOR_INVOCATION,
        '''
class A {
  A(int p);
}
class B extends A {
  int field;
  B() : field = 42, super(0) {}
}
''');
  }

  void test_createConstructorSuperExplicit_named() {
    resolveTestUnit('''
class A {
  A.named(int p);
}
class B extends A {
  B() {}
}
''');
    assertHasFix(
        DartFixKind.ADD_SUPER_CONSTRUCTOR_INVOCATION,
        '''
class A {
  A.named(int p);
}
class B extends A {
  B() : super.named(0) {}
}
''');
  }

  void test_createConstructorSuperExplicit_named_private() {
    resolveTestUnit('''
class A {
  A._named(int p);
}
class B extends A {
  B() {}
}
''');
    assertNoFix(DartFixKind.ADD_SUPER_CONSTRUCTOR_INVOCATION);
  }

  void test_createConstructorSuperExplicit_typeArgument() {
    resolveTestUnit('''
class A<T> {
  A(T p);
}
class B extends A<int> {
  B();
}
''');
    assertHasFix(
        DartFixKind.ADD_SUPER_CONSTRUCTOR_INVOCATION,
        '''
class A<T> {
  A(T p);
}
class B extends A<int> {
  B() : super(0);
}
''');
  }

  void test_createConstructorSuperImplicit() {
    resolveTestUnit('''
class A {
  A(p1, int p2, List<String> p3, [int p4]);
}
class B extends A {
  int existingField;

  void existingMethod() {}
}
''');
    assertHasFix(
        DartFixKind.CREATE_CONSTRUCTOR_SUPER,
        '''
class A {
  A(p1, int p2, List<String> p3, [int p4]);
}
class B extends A {
  int existingField;

  B(p1, int p2, List<String> p3) : super(p1, p2, p3);

  void existingMethod() {}
}
''');
  }

  void test_createConstructorSuperImplicit_fieldInitializer() {
    resolveTestUnit('''
class A {
  int _field;
  A(this._field);
}
class B extends A {
  int existingField;

  void existingMethod() {}
}
''');
    assertHasFix(
        DartFixKind.CREATE_CONSTRUCTOR_SUPER,
        '''
class A {
  int _field;
  A(this._field);
}
class B extends A {
  int existingField;

  B(int field) : super(field);

  void existingMethod() {}
}
''');
  }

  void test_createConstructorSuperImplicit_importType() {
    addSource(
        '/libA.dart',
        r'''
library libA;
class A {}
''');
    addSource(
        '/libB.dart',
        r'''
library libB;
import 'libA.dart';
class B {
  B(A a);
}
''');
    resolveTestUnit('''
import 'libB.dart';
class C extends B {
}
''');
    assertHasFix(
        DartFixKind.CREATE_CONSTRUCTOR_SUPER,
        '''
import 'libB.dart';
import 'libA.dart';
class C extends B {
  C(A a) : super(a);
}
''');
  }

  void test_createConstructorSuperImplicit_named() {
    resolveTestUnit('''
class A {
  A.named(p1, int p2);
}
class B extends A {
  int existingField;

  void existingMethod() {}
}
''');
    assertHasFix(
        DartFixKind.CREATE_CONSTRUCTOR_SUPER,
        '''
class A {
  A.named(p1, int p2);
}
class B extends A {
  int existingField;

  B.named(p1, int p2) : super.named(p1, p2);

  void existingMethod() {}
}
''');
  }

  void test_createConstructorSuperImplicit_private() {
    resolveTestUnit('''
class A {
  A._named(p);
}
class B extends A {
}
''');
    assertNoFix(DartFixKind.CREATE_CONSTRUCTOR_SUPER);
  }

  void test_createConstructorSuperImplicit_typeArgument() {
    resolveTestUnit('''
class C<T> {
  final T x;
  C(this.x);
}
class D extends C<int> {
}''');
    assertHasFix(
        DartFixKind.CREATE_CONSTRUCTOR_SUPER,
        '''
class C<T> {
  final T x;
  C(this.x);
}
class D extends C<int> {
  D(int x) : super(x);
}''');
  }

  void test_createField_BAD_inEnum() {
    resolveTestUnit('''
enum MyEnum {
  AAA, BBB
}
main() {
  MyEnum.foo;
}
''');
    assertNoFix(DartFixKind.CREATE_FIELD);
  }

  void test_createField_BAD_inSDK() {
    resolveTestUnit('''
main(List p) {
  p.foo = 1;
}
''');
    assertNoFix(DartFixKind.CREATE_FIELD);
  }

  void test_createField_getter_multiLevel() {
    resolveTestUnit('''
class A {
}
class B {
  A a;
}
class C {
  B b;
}
main(C c) {
  int v = c.b.a.test;
}
''');
    assertHasFix(
        DartFixKind.CREATE_FIELD,
        '''
class A {
  int test;
}
class B {
  A a;
}
class C {
  B b;
}
main(C c) {
  int v = c.b.a.test;
}
''');
  }

  void test_createField_getter_qualified_instance() {
    resolveTestUnit('''
class A {
}
main(A a) {
  int v = a.test;
}
''');
    assertHasFix(
        DartFixKind.CREATE_FIELD,
        '''
class A {
  int test;
}
main(A a) {
  int v = a.test;
}
''');
  }

  void test_createField_getter_qualified_instance_dynamicType() {
    resolveTestUnit('''
class A {
  B b;
  void f(Object p) {
    p == b.test;
  }
}
class B {
}
''');
    assertHasFix(
        DartFixKind.CREATE_FIELD,
        '''
class A {
  B b;
  void f(Object p) {
    p == b.test;
  }
}
class B {
  var test;
}
''');
  }

  void test_createField_getter_unqualified_instance_asInvocationArgument() {
    resolveTestUnit('''
class A {
  main() {
    f(test);
  }
}
f(String s) {}
''');
    assertHasFix(
        DartFixKind.CREATE_FIELD,
        '''
class A {
  String test;

  main() {
    f(test);
  }
}
f(String s) {}
''');
  }

  void test_createField_getter_unqualified_instance_assignmentRhs() {
    resolveTestUnit('''
class A {
  main() {
    int v = test;
  }
}
''');
    assertHasFix(
        DartFixKind.CREATE_FIELD,
        '''
class A {
  int test;

  main() {
    int v = test;
  }
}
''');
  }

  void test_createField_getter_unqualified_instance_asStatement() {
    resolveTestUnit('''
class A {
  main() {
    test;
  }
}
''');
    assertHasFix(
        DartFixKind.CREATE_FIELD,
        '''
class A {
  var test;

  main() {
    test;
  }
}
''');
  }

  void test_createField_hint() {
    resolveTestUnit('''
class A {
}
main(A a) {
  var x = a;
  int v = x.test;
}
''');
    assertHasFix(
        DartFixKind.CREATE_FIELD,
        '''
class A {
  int test;
}
main(A a) {
  var x = a;
  int v = x.test;
}
''');
  }

  void test_createField_hint_setter() {
    resolveTestUnit('''
class A {
}
main(A a) {
  var x = a;
  x.test = 0;
}
''');
    assertHasFix(
        DartFixKind.CREATE_FIELD,
        '''
class A {
  int test;
}
main(A a) {
  var x = a;
  x.test = 0;
}
''');
  }

  void test_createField_importType() {
    addSource(
        '/libA.dart',
        r'''
library libA;
class A {}
''');
    addSource(
        '/libB.dart',
        r'''
library libB;
import 'libA.dart';
A getA() => null;
''');
    resolveTestUnit('''
import 'libB.dart';
class C {
}
main(C c) {
  c.test = getA();
}
''');
    assertHasFix(
        DartFixKind.CREATE_FIELD,
        '''
import 'libB.dart';
import 'libA.dart';
class C {
  A test;
}
main(C c) {
  c.test = getA();
}
''');
  }

  void test_createField_setter_generic_BAD() {
    resolveTestUnit('''
class A {
}
class B<T> {
  List<T> items;
  main(A a) {
    a.test = items;
  }
}
''');
    assertHasFix(
        DartFixKind.CREATE_FIELD,
        '''
class A {
  List test;
}
class B<T> {
  List<T> items;
  main(A a) {
    a.test = items;
  }
}
''');
  }

  void test_createField_setter_generic_OK_local() {
    resolveTestUnit('''
class A<T> {
  List<T> items;

  main(A a) {
    test = items;
  }
}
''');
    assertHasFix(
        DartFixKind.CREATE_FIELD,
        '''
class A<T> {
  List<T> items;

  List<T> test;

  main(A a) {
    test = items;
  }
}
''');
  }

  void test_createField_setter_qualified_instance_hasField() {
    resolveTestUnit('''
class A {
  int aaa;
  int zzz;

  existingMethod() {}
}
main(A a) {
  a.test = 5;
}
''');
    assertHasFix(
        DartFixKind.CREATE_FIELD,
        '''
class A {
  int aaa;
  int zzz;

  int test;

  existingMethod() {}
}
main(A a) {
  a.test = 5;
}
''');
  }

  void test_createField_setter_qualified_instance_hasMethod() {
    resolveTestUnit('''
class A {
  existingMethod() {}
}
main(A a) {
  a.test = 5;
}
''');
    assertHasFix(
        DartFixKind.CREATE_FIELD,
        '''
class A {
  int test;

  existingMethod() {}
}
main(A a) {
  a.test = 5;
}
''');
  }

  void test_createField_setter_qualified_static() {
    resolveTestUnit('''
class A {
}
main() {
  A.test = 5;
}
''');
    assertHasFix(
        DartFixKind.CREATE_FIELD,
        '''
class A {
  static int test;
}
main() {
  A.test = 5;
}
''');
  }

  void test_createField_setter_unqualified_instance() {
    resolveTestUnit('''
class A {
  main() {
    test = 5;
  }
}
''');
    assertHasFix(
        DartFixKind.CREATE_FIELD,
        '''
class A {
  int test;

  main() {
    test = 5;
  }
}
''');
  }

  void test_createField_setter_unqualified_static() {
    resolveTestUnit('''
class A {
  static main() {
    test = 5;
  }
}
''');
    assertHasFix(
        DartFixKind.CREATE_FIELD,
        '''
class A {
  static int test;

  static main() {
    test = 5;
  }
}
''');
  }

  void test_createFile_forImport() {
    testFile = '/my/project/bin/test.dart';
    resolveTestUnit('''
import 'my_file.dart';
''');
    AnalysisError error = _findErrorToFix();
    fix = _assertHasFix(DartFixKind.CREATE_FILE, error);
    change = fix.change;
    // validate change
    List<SourceFileEdit> fileEdits = change.edits;
    expect(fileEdits, hasLength(1));
    SourceFileEdit fileEdit = change.edits[0];
    expect(fileEdit.file, '/my/project/bin/my_file.dart');
    expect(fileEdit.fileStamp, -1);
    expect(fileEdit.edits, hasLength(1));
    expect(fileEdit.edits[0].replacement, contains('library my_file;'));
  }

  void test_createFile_forImport_inPackage_lib() {
    provider.newFile('/projects/my_package/pubspec.yaml', 'name: my_package');
    testFile = '/projects/my_package/lib/test.dart';
    provider.newFolder('/projects/my_package/lib');
    resolveTestUnit('''
import 'a/bb/c_cc/my_lib.dart';
''');
    AnalysisError error = _findErrorToFix();
    fix = _assertHasFix(DartFixKind.CREATE_FILE, error);
    change = fix.change;
    // validate change
    List<SourceFileEdit> fileEdits = change.edits;
    expect(fileEdits, hasLength(1));
    SourceFileEdit fileEdit = change.edits[0];
    expect(fileEdit.file, '/projects/my_package/lib/a/bb/c_cc/my_lib.dart');
    expect(fileEdit.fileStamp, -1);
    expect(fileEdit.edits, hasLength(1));
    expect(fileEdit.edits[0].replacement,
        contains('library my_package.a.bb.c_cc.my_lib;'));
  }

  void test_createFile_forImport_inPackage_test() {
    provider.newFile('/projects/my_package/pubspec.yaml', 'name: my_package');
    testFile = '/projects/my_package/test/misc/test_all.dart';
    resolveTestUnit('''
import 'a/bb/my_lib.dart';
''');
    AnalysisError error = _findErrorToFix();
    fix = _assertHasFix(DartFixKind.CREATE_FILE, error);
    change = fix.change;
    // validate change
    List<SourceFileEdit> fileEdits = change.edits;
    expect(fileEdits, hasLength(1));
    SourceFileEdit fileEdit = change.edits[0];
    expect(fileEdit.file, '/projects/my_package/test/misc/a/bb/my_lib.dart');
    expect(fileEdit.fileStamp, -1);
    expect(fileEdit.edits, hasLength(1));
    expect(fileEdit.edits[0].replacement,
        contains('library my_package.test.misc.a.bb.my_lib;'));
  }

  void test_createFile_forPart() {
    testFile = '/my/project/bin/test.dart';
    resolveTestUnit('''
library my.lib;
part 'my_part.dart';
''');
    AnalysisError error = _findErrorToFix();
    fix = _assertHasFix(DartFixKind.CREATE_FILE, error);
    change = fix.change;
    // validate change
    List<SourceFileEdit> fileEdits = change.edits;
    expect(fileEdits, hasLength(1));
    SourceFileEdit fileEdit = change.edits[0];
    expect(fileEdit.file, '/my/project/bin/my_part.dart');
    expect(fileEdit.fileStamp, -1);
    expect(fileEdit.edits, hasLength(1));
    expect(fileEdit.edits[0].replacement, contains('part of my.lib;'));
  }

  void test_createFile_forPart_inPackageLib() {
    provider.newFile(
        '/my/pubspec.yaml',
        r'''
name: my_test
''');
    testFile = '/my/lib/test.dart';
    addTestSource(
        '''
library my.lib;
part 'my_part.dart';
''',
        Uri.parse('package:my/test.dart'));
    // configure SourceFactory
    UriResolver pkgResolver = new PackageMapUriResolver(provider, {
      'my': [provider.getResource('/my/lib')],
    });
    context.sourceFactory = new SourceFactory(
        [AbstractContextTest.SDK_RESOLVER, pkgResolver, resourceResolver]);
    // prepare fix
    testUnit = resolveLibraryUnit(testSource);
    AnalysisError error = _findErrorToFix();
    fix = _assertHasFix(DartFixKind.CREATE_FILE, error);
    change = fix.change;
    // validate change
    List<SourceFileEdit> fileEdits = change.edits;
    expect(fileEdits, hasLength(1));
    SourceFileEdit fileEdit = change.edits[0];
    expect(fileEdit.file, '/my/lib/my_part.dart');
    expect(fileEdit.fileStamp, -1);
    expect(fileEdit.edits, hasLength(1));
    expect(fileEdit.edits[0].replacement, contains('part of my.lib;'));
  }

  void test_createGetter_BAD_inSDK() {
    resolveTestUnit('''
main(List p) {
  int v = p.foo;
}
''');
    assertNoFix(DartFixKind.CREATE_GETTER);
  }

  void test_createGetter_hint_getter() {
    resolveTestUnit('''
class A {
}
main(A a) {
  var x = a;
  int v = x.test;
}
''');
    assertHasFix(
        DartFixKind.CREATE_GETTER,
        '''
class A {
  int get test => null;
}
main(A a) {
  var x = a;
  int v = x.test;
}
''');
  }

  void test_createGetter_location_afterLastGetter() {
    resolveTestUnit('''
class A {
  int existingField;

  int get existingGetter => null;

  existingMethod() {}
}
main(A a) {
  int v = a.test;
}
''');
    assertHasFix(
        DartFixKind.CREATE_GETTER,
        '''
class A {
  int existingField;

  int get existingGetter => null;

  int get test => null;

  existingMethod() {}
}
main(A a) {
  int v = a.test;
}
''');
  }

  void test_createGetter_multiLevel() {
    resolveTestUnit('''
class A {
}
class B {
  A a;
}
class C {
  B b;
}
main(C c) {
  int v = c.b.a.test;
}
''');
    assertHasFix(
        DartFixKind.CREATE_GETTER,
        '''
class A {
  int get test => null;
}
class B {
  A a;
}
class C {
  B b;
}
main(C c) {
  int v = c.b.a.test;
}
''');
  }

  void test_createGetter_qualified_instance() {
    resolveTestUnit('''
class A {
}
main(A a) {
  int v = a.test;
}
''');
    assertHasFix(
        DartFixKind.CREATE_GETTER,
        '''
class A {
  int get test => null;
}
main(A a) {
  int v = a.test;
}
''');
  }

  void test_createGetter_qualified_instance_dynamicType() {
    resolveTestUnit('''
class A {
  B b;
  void f(Object p) {
    p == b.test;
  }
}
class B {
}
''');
    assertHasFix(
        DartFixKind.CREATE_GETTER,
        '''
class A {
  B b;
  void f(Object p) {
    p == b.test;
  }
}
class B {
  get test => null;
}
''');
  }

  void test_createGetter_setterContext() {
    resolveTestUnit('''
class A {
}
main(A a) {
  a.test = 42;
}
''');
    assertNoFix(DartFixKind.CREATE_GETTER);
  }

  void test_createGetter_unqualified_instance_asInvocationArgument() {
    resolveTestUnit('''
class A {
  main() {
    f(test);
  }
}
f(String s) {}
''');
    assertHasFix(
        DartFixKind.CREATE_GETTER,
        '''
class A {
  String get test => null;

  main() {
    f(test);
  }
}
f(String s) {}
''');
  }

  void test_createGetter_unqualified_instance_assignmentLhs() {
    resolveTestUnit('''
class A {
  main() {
    test = 42;
  }
}
''');
    assertNoFix(DartFixKind.CREATE_GETTER);
  }

  void test_createGetter_unqualified_instance_assignmentRhs() {
    resolveTestUnit('''
class A {
  main() {
    int v = test;
  }
}
''');
    assertHasFix(
        DartFixKind.CREATE_GETTER,
        '''
class A {
  int get test => null;

  main() {
    int v = test;
  }
}
''');
  }

  void test_createGetter_unqualified_instance_asStatement() {
    resolveTestUnit('''
class A {
  main() {
    test;
  }
}
''');
    assertHasFix(
        DartFixKind.CREATE_GETTER,
        '''
class A {
  get test => null;

  main() {
    test;
  }
}
''');
  }

  void test_createLocalVariable_functionType_named() {
    resolveTestUnit('''
typedef MY_FUNCTION(int p);
foo(MY_FUNCTION f) {}
main() {
  foo(bar);
}
''');
    assertHasFix(
        DartFixKind.CREATE_LOCAL_VARIABLE,
        '''
typedef MY_FUNCTION(int p);
foo(MY_FUNCTION f) {}
main() {
  MY_FUNCTION bar;
  foo(bar);
}
''');
  }

  void test_createLocalVariable_functionType_synthetic() {
    resolveTestUnit('''
foo(f(int p)) {}
main() {
  foo(bar);
}
''');
    assertNoFix(DartFixKind.CREATE_LOCAL_VARIABLE);
  }

  void test_createLocalVariable_read_typeAssignment() {
    resolveTestUnit('''
main() {
  int a = test;
}
''');
    assertHasFix(
        DartFixKind.CREATE_LOCAL_VARIABLE,
        '''
main() {
  int test;
  int a = test;
}
''');
  }

  void test_createLocalVariable_read_typeCondition() {
    resolveTestUnit('''
main() {
  if (!test) {
    print(42);
  }
}
''');
    assertHasFix(
        DartFixKind.CREATE_LOCAL_VARIABLE,
        '''
main() {
  bool test;
  if (!test) {
    print(42);
  }
}
''');
  }

  void test_createLocalVariable_read_typeInvocationArgument() {
    resolveTestUnit('''
main() {
  f(test);
}
f(String p) {}
''');
    assertHasFix(
        DartFixKind.CREATE_LOCAL_VARIABLE,
        '''
main() {
  String test;
  f(test);
}
f(String p) {}
''');
    _assertLinkedGroup(change.linkedEditGroups[0], ['String test;']);
    _assertLinkedGroup(change.linkedEditGroups[1], ['test;', 'test);']);
  }

  void test_createLocalVariable_read_typeInvocationTarget() {
    resolveTestUnit('''
main() {
  test.add('hello');
}
''');
    assertHasFix(
        DartFixKind.CREATE_LOCAL_VARIABLE,
        '''
main() {
  var test;
  test.add('hello');
}
''');
    _assertLinkedGroup(change.linkedEditGroups[0], ['test;', 'test.add(']);
  }

  void test_createLocalVariable_write_assignment() {
    resolveTestUnit('''
main() {
  test = 42;
}
''');
    assertHasFix(
        DartFixKind.CREATE_LOCAL_VARIABLE,
        '''
main() {
  var test = 42;
}
''');
  }

  void test_createLocalVariable_write_assignment_compound() {
    resolveTestUnit('''
main() {
  test += 42;
}
''');
    assertHasFix(
        DartFixKind.CREATE_LOCAL_VARIABLE,
        '''
main() {
  int test;
  test += 42;
}
''');
  }

  void test_createMissingOverrides_functionTypeAlias() {
    resolveTestUnit('''
typedef int Binary(int left, int right);

abstract class Emulator {
  void performBinary(Binary binary);
}

class MyEmulator extends Emulator {
}
''');
    assertHasFix(
        DartFixKind.CREATE_MISSING_OVERRIDES,
        '''
typedef int Binary(int left, int right);

abstract class Emulator {
  void performBinary(Binary binary);
}

class MyEmulator extends Emulator {
  @override
  void performBinary(Binary binary) {
    // TODO: implement performBinary
  }
}
''');
  }

  void test_createMissingOverrides_functionTypedParameter() {
    resolveTestUnit('''
abstract class A {
  forEach(int f(double p1, String p2));
}

class B extends A {
}
''');
    assertHasFix(
        DartFixKind.CREATE_MISSING_OVERRIDES,
        '''
abstract class A {
  forEach(int f(double p1, String p2));
}

class B extends A {
  @override
  forEach(int f(double p1, String p2)) {
    // TODO: implement forEach
  }
}
''');
  }

  void test_createMissingOverrides_generics_typeArguments() {
    resolveTestUnit('''
class Iterator<T> {
}

abstract class IterableMixin<T> {
  Iterator<T> get iterator;
}

class Test extends IterableMixin<int> {
}
''');
    assertHasFix(
        DartFixKind.CREATE_MISSING_OVERRIDES,
        '''
class Iterator<T> {
}

abstract class IterableMixin<T> {
  Iterator<T> get iterator;
}

class Test extends IterableMixin<int> {
  // TODO: implement iterator
  @override
  Iterator<int> get iterator => null;
}
''');
  }

  void test_createMissingOverrides_generics_typeParameters() {
    resolveTestUnit('''
abstract class ItemProvider<T> {
  List<T> getItems();
}

class Test<V> extends ItemProvider<V> {
}
''');
    assertHasFix(
        DartFixKind.CREATE_MISSING_OVERRIDES,
        '''
abstract class ItemProvider<T> {
  List<T> getItems();
}

class Test<V> extends ItemProvider<V> {
  @override
  List<V> getItems() {
    // TODO: implement getItems
  }
}
''');
  }

  void test_createMissingOverrides_getter() {
    resolveTestUnit('''
abstract class A {
  get g1;
  int get g2;
}

class B extends A {
}
''');
    assertHasFix(
        DartFixKind.CREATE_MISSING_OVERRIDES,
        '''
abstract class A {
  get g1;
  int get g2;
}

class B extends A {
  // TODO: implement g1
  @override
  get g1 => null;

  // TODO: implement g2
  @override
  int get g2 => null;
}
''');
  }

  void test_createMissingOverrides_importPrefix() {
    resolveTestUnit('''
import 'dart:async' as aaa;
abstract class A {
  Map<aaa.Future, List<aaa.Future>> g(aaa.Future p);
}

class B extends A {
}
''');
    assertHasFix(
        DartFixKind.CREATE_MISSING_OVERRIDES,
        '''
import 'dart:async' as aaa;
abstract class A {
  Map<aaa.Future, List<aaa.Future>> g(aaa.Future p);
}

class B extends A {
  @override
  Map<aaa.Future, List<aaa.Future>> g(aaa.Future p) {
    // TODO: implement g
  }
}
''');
  }

  void test_createMissingOverrides_mergeToField_getterSetter() {
    resolveTestUnit('''
class A {
  int ma;
  void mb() {}
  double mc;
}

class B implements A {
}
''');
    assertHasFix(
        DartFixKind.CREATE_MISSING_OVERRIDES,
        '''
class A {
  int ma;
  void mb() {}
  double mc;
}

class B implements A {
  int ma;

  double mc;

  @override
  void mb() {
    // TODO: implement mb
  }
}
''');
  }

  void test_createMissingOverrides_method() {
    resolveTestUnit('''
abstract class A {
  m1();
  int m2();
  String m3(int p1, double p2, Map<int, List<String>> p3);
  String m4(p1, p2);
  String m5(p1, [int p2 = 2, int p3, p4 = 4]);
  String m6(p1, {int p2: 2, int p3, p4: 4});
}

class B extends A {
}
''');
    String expectedCode = '''
abstract class A {
  m1();
  int m2();
  String m3(int p1, double p2, Map<int, List<String>> p3);
  String m4(p1, p2);
  String m5(p1, [int p2 = 2, int p3, p4 = 4]);
  String m6(p1, {int p2: 2, int p3, p4: 4});
}

class B extends A {
  @override
  m1() {
    // TODO: implement m1
  }

  @override
  int m2() {
    // TODO: implement m2
  }

  @override
  String m3(int p1, double p2, Map<int, List<String>> p3) {
    // TODO: implement m3
  }

  @override
  String m4(p1, p2) {
    // TODO: implement m4
  }

  @override
  String m5(p1, [int p2 = 2, int p3, p4 = 4]) {
    // TODO: implement m5
  }

  @override
  String m6(p1, {int p2: 2, int p3, p4: 4}) {
    // TODO: implement m6
  }
}
''';
    assertHasFix(DartFixKind.CREATE_MISSING_OVERRIDES, expectedCode);
    // end position should be on "m1", not on "m2", "m3", etc
    {
      Position endPosition = change.selection;
      expect(endPosition, isNotNull);
      expect(endPosition.file, testFile);
      int endOffset = endPosition.offset;
      String endString = expectedCode.substring(endOffset, endOffset + 25);
      expect(endString, contains('m1'));
      expect(endString, isNot(contains('m2')));
      expect(endString, isNot(contains('m3')));
      expect(endString, isNot(contains('m4')));
      expect(endString, isNot(contains('m5')));
      expect(endString, isNot(contains('m6')));
    }
  }

  void test_createMissingOverrides_operator() {
    resolveTestUnit('''
abstract class A {
  int operator [](int index);
  void operator []=(int index, String value);
}

class B extends A {
}
''');
    assertHasFix(
        DartFixKind.CREATE_MISSING_OVERRIDES,
        '''
abstract class A {
  int operator [](int index);
  void operator []=(int index, String value);
}

class B extends A {
  @override
  int operator [](int index) {
    // TODO: implement []
  }

  @override
  void operator []=(int index, String value) {
    // TODO: implement []=
  }
}
''');
  }

  void test_createMissingOverrides_setter() {
    resolveTestUnit('''
abstract class A {
  set s1(x);
  set s2(int x);
  void set s3(String x);
}

class B extends A {
}
''');
    assertHasFix(
        DartFixKind.CREATE_MISSING_OVERRIDES,
        '''
abstract class A {
  set s1(x);
  set s2(int x);
  void set s3(String x);
}

class B extends A {
  @override
  set s1(x) {
    // TODO: implement s1
  }

  @override
  set s2(int x) {
    // TODO: implement s2
  }

  @override
  void set s3(String x) {
    // TODO: implement s3
  }
}
''');
  }

  void test_createNoSuchMethod() {
    resolveTestUnit('''
abstract class A {
  m1();
  int m2();
}

class B extends A {
  existing() {}
}
''');
    assertHasFix(
        DartFixKind.CREATE_NO_SUCH_METHOD,
        '''
abstract class A {
  m1();
  int m2();
}

class B extends A {
  existing() {}

  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
''');
  }

  void test_creationFunction_forFunctionType_cascadeSecond() {
    resolveTestUnit('''
class A {
  B ma() => null;
}
class B {
  useFunction(int g(double a, String b)) {}
}

main() {
  A a = new A();
  a..ma().useFunction(test);
}
''');
    assertHasFix(
        DartFixKind.CREATE_FUNCTION,
        '''
class A {
  B ma() => null;
}
class B {
  useFunction(int g(double a, String b)) {}
}

main() {
  A a = new A();
  a..ma().useFunction(test);
}

int test(double a, String b) {
}
''');
  }

  void test_creationFunction_forFunctionType_coreFunction() {
    resolveTestUnit('''
main() {
  useFunction(g: test);
}
useFunction({Function g}) {}
''');
    assertHasFix(
        DartFixKind.CREATE_FUNCTION,
        '''
main() {
  useFunction(g: test);
}
useFunction({Function g}) {}

test() {
}
''');
  }

  void test_creationFunction_forFunctionType_dynamicArgument() {
    resolveTestUnit('''
main() {
  useFunction(test);
}
useFunction(int g(a, b)) {}
''');
    assertHasFix(
        DartFixKind.CREATE_FUNCTION,
        '''
main() {
  useFunction(test);
}
useFunction(int g(a, b)) {}

int test(a, b) {
}
''');
  }

  void test_creationFunction_forFunctionType_function() {
    resolveTestUnit('''
main() {
  useFunction(test);
}
useFunction(int g(double a, String b)) {}
''');
    assertHasFix(
        DartFixKind.CREATE_FUNCTION,
        '''
main() {
  useFunction(test);
}
useFunction(int g(double a, String b)) {}

int test(double a, String b) {
}
''');
  }

  void test_creationFunction_forFunctionType_function_namedArgument() {
    resolveTestUnit('''
main() {
  useFunction(g: test);
}
useFunction({int g(double a, String b)}) {}
''');
    assertHasFix(
        DartFixKind.CREATE_FUNCTION,
        '''
main() {
  useFunction(g: test);
}
useFunction({int g(double a, String b)}) {}

int test(double a, String b) {
}
''');
  }

  void test_creationFunction_forFunctionType_importType() {
    addSource(
        '/libA.dart',
        r'''
library libA;
class A {}
''');
    addSource(
        '/libB.dart',
        r'''
library libB;
import 'libA.dart';
useFunction(int g(A a)) {}
''');
    resolveTestUnit('''
import 'libB.dart';
main() {
  useFunction(test);
}
''');
    assertHasFix(
        DartFixKind.CREATE_FUNCTION,
        '''
import 'libB.dart';
import 'libA.dart';
main() {
  useFunction(test);
}

int test(A a) {
}
''');
  }

  void test_creationFunction_forFunctionType_method_enclosingClass_static() {
    resolveTestUnit('''
class A {
  static foo() {
    useFunction(test);
  }
}
useFunction(int g(double a, String b)) {}
''');
    assertHasFix(
        DartFixKind.CREATE_METHOD,
        '''
class A {
  static foo() {
    useFunction(test);
  }

  static int test(double a, String b) {
  }
}
useFunction(int g(double a, String b)) {}
''');
  }

  void test_creationFunction_forFunctionType_method_enclosingClass_static2() {
    resolveTestUnit('''
class A {
  var f;
  A() : f = useFunction(test);
}
useFunction(int g(double a, String b)) {}
''');
    assertHasFix(
        DartFixKind.CREATE_METHOD,
        '''
class A {
  var f;
  A() : f = useFunction(test);

  static int test(double a, String b) {
  }
}
useFunction(int g(double a, String b)) {}
''');
  }

  void test_creationFunction_forFunctionType_method_targetClass() {
    resolveTestUnit('''
main(A a) {
  useFunction(a.test);
}
class A {
}
useFunction(int g(double a, String b)) {}
''');
    assertHasFix(
        DartFixKind.CREATE_METHOD,
        '''
main(A a) {
  useFunction(a.test);
}
class A {
  int test(double a, String b) {
  }
}
useFunction(int g(double a, String b)) {}
''');
  }

  void test_creationFunction_forFunctionType_method_targetClass_hasOtherMember() {
    resolveTestUnit('''
main(A a) {
  useFunction(a.test);
}
class A {
  m() {}
}
useFunction(int g(double a, String b)) {}
''');
    assertHasFix(
        DartFixKind.CREATE_METHOD,
        '''
main(A a) {
  useFunction(a.test);
}
class A {
  m() {}

  int test(double a, String b) {
  }
}
useFunction(int g(double a, String b)) {}
''');
  }

  void test_creationFunction_forFunctionType_notFunctionType() {
    resolveTestUnit('''
main(A a) {
  useFunction(a.test);
}
typedef A();
useFunction(g) {}
''');
    assertNoFix(DartFixKind.CREATE_METHOD);
    assertNoFix(DartFixKind.CREATE_FUNCTION);
  }

  void test_creationFunction_forFunctionType_unknownTarget() {
    resolveTestUnit('''
main(A a) {
  useFunction(a.test);
}
class A {
}
useFunction(g) {}
''');
    assertNoFix(DartFixKind.CREATE_METHOD);
  }

  void test_expectedToken_semicolon() {
    resolveTestUnit('''
main() {
  print(0)
}
''');
    assertHasFix(
        DartFixKind.INSERT_SEMICOLON,
        '''
main() {
  print(0);
}
''');
  }

  void test_illegalAsyncReturnType_asyncLibrary_import() {
    errorFilter = (AnalysisError error) {
      return error.errorCode == StaticTypeWarningCode.ILLEGAL_ASYNC_RETURN_TYPE;
    };
    resolveTestUnit('''
library main;
int main() async {
}
''');
    assertHasFix(
        DartFixKind.REPLACE_RETURN_TYPE_FUTURE,
        '''
library main;
import 'dart:async';
Future<int> main() async {
}
''');
  }

  void test_illegalAsyncReturnType_asyncLibrary_usePrefix() {
    errorFilter = (AnalysisError error) {
      return error.errorCode == StaticTypeWarningCode.ILLEGAL_ASYNC_RETURN_TYPE;
    };
    resolveTestUnit('''
import 'dart:async' as al;
int main() async {
}
''');
    assertHasFix(
        DartFixKind.REPLACE_RETURN_TYPE_FUTURE,
        '''
import 'dart:async' as al;
al.Future<int> main() async {
}
''');
  }

  void test_illegalAsyncReturnType_complexTypeName() {
    errorFilter = (AnalysisError error) {
      return error.errorCode == StaticTypeWarningCode.ILLEGAL_ASYNC_RETURN_TYPE;
    };
    resolveTestUnit('''
import 'dart:async';
List<int> main() async {
}
''');
    assertHasFix(
        DartFixKind.REPLACE_RETURN_TYPE_FUTURE,
        '''
import 'dart:async';
Future<List<int>> main() async {
}
''');
  }

  void test_illegalAsyncReturnType_void() {
    errorFilter = (AnalysisError error) {
      return error.errorCode == StaticTypeWarningCode.ILLEGAL_ASYNC_RETURN_TYPE;
    };
    resolveTestUnit('''
import 'dart:async';
void main() async {
}
''');
    assertHasFix(
        DartFixKind.REPLACE_RETURN_TYPE_FUTURE,
        '''
import 'dart:async';
Future main() async {
}
''');
  }

  void test_importLibraryPackage_withClass() {
    _configureMyPkg('''
library my_lib;
class Test {}
''');
    // try to find a fix
    resolveTestUnit('''
main() {
  Test test = null;
}
''');
    performAllAnalysisTasks();
    assertHasFix(
        DartFixKind.IMPORT_LIBRARY_PROJECT,
        '''
import 'package:my_pkg/my_lib.dart';

main() {
  Test test = null;
}
''');
  }

  void test_importLibraryProject_withClass_annotation() {
    addSource(
        '/lib.dart',
        '''
library lib;
class Test {
  const Test(int p);
}
''');
    resolveTestUnit('''
@Test(0)
main() {
}
''');
    performAllAnalysisTasks();
    assertHasFix(
        DartFixKind.IMPORT_LIBRARY_PROJECT,
        '''
import 'lib.dart';

@Test(0)
main() {
}
''');
  }

  void test_importLibraryProject_withClass_hasOtherLibraryWithPrefix() {
    testFile = '/project/bin/test.dart';
    addSource(
        '/project/bin/a.dart',
        '''
library a;
class One {}
''');
    addSource(
        '/project/bin/b.dart',
        '''
library b;
class One {}
class Two {}
''');
    resolveTestUnit('''
import 'b.dart' show Two;
main () {
  new Two();
  new One();
}
''');
    performAllAnalysisTasks();
    assertHasFix(
        DartFixKind.IMPORT_LIBRARY_PROJECT,
        '''
import 'b.dart' show Two;
import 'a.dart';
main () {
  new Two();
  new One();
}
''');
  }

  void test_importLibraryProject_withClass_inParentFolder() {
    testFile = '/project/bin/test.dart';
    addSource(
        '/project/lib.dart',
        '''
library lib;
class Test {}
''');
    resolveTestUnit('''
main() {
  Test t = null;
}
''');
    performAllAnalysisTasks();
    assertHasFix(
        DartFixKind.IMPORT_LIBRARY_PROJECT,
        '''
import '../lib.dart';

main() {
  Test t = null;
}
''');
  }

  void test_importLibraryProject_withClass_inRelativeFolder() {
    testFile = '/project/bin/test.dart';
    addSource(
        '/project/lib/sub/folder/lib.dart',
        '''
library lib;
class Test {}
''');
    resolveTestUnit('''
main() {
  Test t = null;
}
''');
    performAllAnalysisTasks();
    assertHasFix(
        DartFixKind.IMPORT_LIBRARY_PROJECT,
        '''
import '../lib/sub/folder/lib.dart';

main() {
  Test t = null;
}
''');
  }

  void test_importLibraryProject_withClass_inSameFolder() {
    testFile = '/project/bin/test.dart';
    addSource(
        '/project/bin/lib.dart',
        '''
library lib;
class Test {}
''');
    resolveTestUnit('''
main() {
  Test t = null;
}
''');
    performAllAnalysisTasks();
    assertHasFix(
        DartFixKind.IMPORT_LIBRARY_PROJECT,
        '''
import 'lib.dart';

main() {
  Test t = null;
}
''');
  }

  void test_importLibraryProject_withFunction() {
    addSource(
        '/lib.dart',
        '''
library lib;
myFunction() {}
''');
    resolveTestUnit('''
main() {
  myFunction();
}
''');
    performAllAnalysisTasks();
    assertHasFix(
        DartFixKind.IMPORT_LIBRARY_PROJECT,
        '''
import 'lib.dart';

main() {
  myFunction();
}
''');
  }

  void test_importLibraryProject_withFunction_unresolvedMethod() {
    addSource(
        '/lib.dart',
        '''
library lib;
myFunction() {}
''');
    resolveTestUnit('''
class A {
  main() {
    myFunction();
  }
}
''');
    performAllAnalysisTasks();
    assertHasFix(
        DartFixKind.IMPORT_LIBRARY_PROJECT,
        '''
import 'lib.dart';

class A {
  main() {
    myFunction();
  }
}
''');
  }

  void test_importLibraryProject_withFunctionTypeAlias() {
    testFile = '/project/bin/test.dart';
    addSource(
        '/project/bin/lib.dart',
        '''
library lib;
typedef MyFunction();
''');
    resolveTestUnit('''
main() {
  MyFunction t = null;
}
''');
    performAllAnalysisTasks();
    assertHasFix(
        DartFixKind.IMPORT_LIBRARY_PROJECT,
        '''
import 'lib.dart';

main() {
  MyFunction t = null;
}
''');
  }

  void test_importLibraryProject_withTopLevelVariable() {
    addSource(
        '/lib.dart',
        '''
library lib;
int MY_VAR = 42;
''');
    resolveTestUnit('''
main() {
  print(MY_VAR);
}
''');
    performAllAnalysisTasks();
    assertHasFix(
        DartFixKind.IMPORT_LIBRARY_PROJECT,
        '''
import 'lib.dart';

main() {
  print(MY_VAR);
}
''');
  }

  void test_importLibrarySdk_withClass_AsExpression() {
    resolveTestUnit('''
main(p) {
  p as Future;
}
''');
    assertHasFix(
        DartFixKind.IMPORT_LIBRARY_SDK,
        '''
import 'dart:async';

main(p) {
  p as Future;
}
''');
  }

  void test_importLibrarySdk_withClass_invocationTarget() {
    resolveTestUnit('''
main() {
  Future.wait(null);
}
''');
    assertHasFix(
        DartFixKind.IMPORT_LIBRARY_SDK,
        '''
import 'dart:async';

main() {
  Future.wait(null);
}
''');
  }

  void test_importLibrarySdk_withClass_IsExpression() {
    resolveTestUnit('''
main(p) {
  p is Future;
}
''');
    assertHasFix(
        DartFixKind.IMPORT_LIBRARY_SDK,
        '''
import 'dart:async';

main(p) {
  p is Future;
}
''');
  }

  void test_importLibrarySdk_withClass_itemOfList() {
    resolveTestUnit('''
main() {
  var a = [Future];
}
''');
    performAllAnalysisTasks();
    assertHasFix(
        DartFixKind.IMPORT_LIBRARY_SDK,
        '''
import 'dart:async';

main() {
  var a = [Future];
}
''');
  }

  void test_importLibrarySdk_withClass_itemOfList_inAnnotation() {
    errorFilter = (AnalysisError error) {
      return error.errorCode == StaticWarningCode.UNDEFINED_IDENTIFIER;
    };
    resolveTestUnit('''
class MyAnnotation {
  const MyAnnotation(a, b);
}
@MyAnnotation(int, const [Future])
main() {}
''');
    assertHasFix(
        DartFixKind.IMPORT_LIBRARY_SDK,
        '''
import 'dart:async';

class MyAnnotation {
  const MyAnnotation(a, b);
}
@MyAnnotation(int, const [Future])
main() {}
''');
  }

  void test_importLibrarySdk_withClass_typeAnnotation() {
    resolveTestUnit('''
main() {
  Future f = null;
}
''');
    assertHasFix(
        DartFixKind.IMPORT_LIBRARY_SDK,
        '''
import 'dart:async';

main() {
  Future f = null;
}
''');
  }

  void test_importLibrarySdk_withClass_typeAnnotation_PrefixedIdentifier() {
    resolveTestUnit('''
main() {
  Future.wait;
}
''');
    assertHasFix(
        DartFixKind.IMPORT_LIBRARY_SDK,
        '''
import 'dart:async';

main() {
  Future.wait;
}
''');
  }

  void test_importLibrarySdk_withClass_typeArgument() {
    resolveTestUnit('''
main() {
  List<Future> futures = [];
}
''');
    assertHasFix(
        DartFixKind.IMPORT_LIBRARY_SDK,
        '''
import 'dart:async';

main() {
  List<Future> futures = [];
}
''');
  }

  void test_importLibrarySdk_withTopLevelVariable() {
    resolveTestUnit('''
main() {
  print(PI);
}
''');
    performAllAnalysisTasks();
    assertHasFix(
        DartFixKind.IMPORT_LIBRARY_SDK,
        '''
import 'dart:math';

main() {
  print(PI);
}
''');
  }

  void test_importLibrarySdk_withTopLevelVariable_annotation() {
    resolveTestUnit('''
@PI
main() {
}
''');
    performAllAnalysisTasks();
    assertHasFix(
        DartFixKind.IMPORT_LIBRARY_SDK,
        '''
import 'dart:math';

@PI
main() {
}
''');
  }

  void test_importLibraryShow() {
    resolveTestUnit('''
import 'dart:async' show Stream;
main() {
  Stream s = null;
  Future f = null;
}
''');
    assertHasFix(
        DartFixKind.IMPORT_LIBRARY_SHOW,
        '''
import 'dart:async' show Future, Stream;
main() {
  Stream s = null;
  Future f = null;
}
''');
  }

  void test_isNotNull() {
    resolveTestUnit('''
main(p) {
  p is! Null;
}
''');
    assertHasFix(
        DartFixKind.USE_NOT_EQ_NULL,
        '''
main(p) {
  p != null;
}
''');
  }

  void test_isNull() {
    resolveTestUnit('''
main(p) {
  p is Null;
}
''');
    assertHasFix(
        DartFixKind.USE_EQ_EQ_NULL,
        '''
main(p) {
  p == null;
}
''');
  }

  void test_makeEnclosingClassAbstract_declaresAbstractMethod() {
    resolveTestUnit('''
class A {
  m();
}
''');
    assertHasFix(
        DartFixKind.MAKE_CLASS_ABSTRACT,
        '''
abstract class A {
  m();
}
''');
  }

  void test_makeEnclosingClassAbstract_inheritsAbstractMethod() {
    resolveTestUnit('''
abstract class A {
  m();
}
class B extends A {
}
''');
    assertHasFix(
        DartFixKind.MAKE_CLASS_ABSTRACT,
        '''
abstract class A {
  m();
}
abstract class B extends A {
}
''');
  }

  void test_noException_1() {
    resolveTestUnit('''
main(p) {
  p i s Null;
}''');
    List<AnalysisError> errors = context.computeErrors(testSource);
    for (var error in errors) {
      _computeFixes(error);
    }
  }

  void test_nonBoolCondition_addNotNull() {
    resolveTestUnit('''
main(String p) {
  if (p) {
    print(p);
  }
}
''');
    assertHasFix(
        DartFixKind.ADD_NE_NULL,
        '''
main(String p) {
  if (p != null) {
    print(p);
  }
}
''');
  }

  void test_removeDeadCode_condition() {
    resolveTestUnit('''
main(int p) {
  if (true || p > 5) {
    print(1);
  }
}
''');
    assertHasFix(
        DartFixKind.REMOVE_DEAD_CODE,
        '''
main(int p) {
  if (true) {
    print(1);
  }
}
''');
  }

  void test_removeDeadCode_statements_one() {
    resolveTestUnit('''
int main() {
  print(0);
  return 42;
  print(1);
}
''');
    assertHasFix(
        DartFixKind.REMOVE_DEAD_CODE,
        '''
int main() {
  print(0);
  return 42;
}
''');
  }

  void test_removeDeadCode_statements_two() {
    resolveTestUnit('''
int main() {
  print(0);
  return 42;
  print(1);
  print(2);
}
''');
    assertHasFix(
        DartFixKind.REMOVE_DEAD_CODE,
        '''
int main() {
  print(0);
  return 42;
}
''');
  }

  void test_removeParentheses_inGetterDeclaration() {
    resolveTestUnit('''
class A {
  int get foo() => 0;
}
''');
    assertHasFix(
        DartFixKind.REMOVE_PARAMETERS_IN_GETTER_DECLARATION,
        '''
class A {
  int get foo => 0;
}
''');
  }

  void test_removeParentheses_inGetterInvocation() {
    resolveTestUnit('''
class A {
  int get foo => 0;
}
main(A a) {
  a.foo();
}
''');
    assertHasFix(
        DartFixKind.REMOVE_PARENTHESIS_IN_GETTER_INVOCATION,
        '''
class A {
  int get foo => 0;
}
main(A a) {
  a.foo;
}
''');
  }

  void test_removeUnnecessaryCast_assignment() {
    resolveTestUnit('''
main(Object p) {
  if (p is String) {
    String v = ((p as String));
  }
}
''');
    assertHasFix(
        DartFixKind.REMOVE_UNNECESSARY_CAST,
        '''
main(Object p) {
  if (p is String) {
    String v = p;
  }
}
''');
  }

  void test_removeUnusedCatchClause() {
    errorFilter = (AnalysisError error) => true;
    resolveTestUnit('''
main() {
  try {
    throw 42;
  } on int catch (e) {
  }
}
''');
    assertHasFix(
        DartFixKind.REMOVE_UNUSED_CATCH_CLAUSE,
        '''
main() {
  try {
    throw 42;
  } on int {
  }
}
''');
  }

  void test_removeUnusedCatchStack() {
    errorFilter = (AnalysisError error) => true;
    resolveTestUnit('''
main() {
  try {
    throw 42;
  } catch (e, stack) {
  }
}
''');
    assertHasFix(
        DartFixKind.REMOVE_UNUSED_CATCH_STACK,
        '''
main() {
  try {
    throw 42;
  } catch (e) {
  }
}
''');
  }

  void test_removeUnusedImport() {
    resolveTestUnit('''
import 'dart:math';
main() {
}
''');
    assertHasFix(
        DartFixKind.REMOVE_UNUSED_IMPORT,
        '''
main() {
}
''');
  }

  void test_removeUnusedImport_anotherImportOnLine() {
    resolveTestUnit('''
import 'dart:math'; import 'dart:async';

main() {
  Future f;
}
''');
    assertHasFix(
        DartFixKind.REMOVE_UNUSED_IMPORT,
        '''
import 'dart:async';

main() {
  Future f;
}
''');
  }

  void test_removeUnusedImport_severalLines() {
    resolveTestUnit('''
import
  'dart:math';
main() {
}
''');
    assertHasFix(
        DartFixKind.REMOVE_UNUSED_IMPORT,
        '''
main() {
}
''');
  }

  void test_replaceImportUri_inProject() {
    testFile = '/project/bin/test.dart';
    addSource('/project/foo/bar/lib.dart', '');
    resolveTestUnit('''
import 'no/matter/lib.dart';
''');
    performAllAnalysisTasks();
    assertHasFix(
        DartFixKind.REPLACE_IMPORT_URI,
        '''
import '../foo/bar/lib.dart';
''');
  }

  void test_replaceImportUri_package() {
    _configureMyPkg('');
    resolveTestUnit('''
import 'no/matter/my_lib.dart';
''');
    performAllAnalysisTasks();
    assertHasFix(
        DartFixKind.REPLACE_IMPORT_URI,
        '''
import 'package:my_pkg/my_lib.dart';
''');
  }

  void test_replaceVarWithDynamic() {
    errorFilter = (AnalysisError error) {
      return error.errorCode == ParserErrorCode.VAR_AS_TYPE_NAME;
    };
    resolveTestUnit('''
class A {
  Map<String, var> m;
}
''');
    assertHasFix(
        DartFixKind.REPLACE_VAR_WITH_DYNAMIC,
        '''
class A {
  Map<String, dynamic> m;
}
''');
  }

  void test_replaceWithConstInstanceCreation() {
    resolveTestUnit('''
class A {
  const A();
}
const a = new A();
''');
    assertHasFix(
        DartFixKind.USE_CONST,
        '''
class A {
  const A();
}
const a = const A();
''');
  }

  void test_undefinedClass_useSimilar_fromImport() {
    resolveTestUnit('''
main() {
  Stirng s = 'abc';
}
''');
    assertHasFix(
        DartFixKind.CHANGE_TO,
        '''
main() {
  String s = 'abc';
}
''');
  }

  void test_undefinedClass_useSimilar_fromThisLibrary() {
    resolveTestUnit('''
class MyClass {}
main() {
  MyCalss v = null;
}
''');
    assertHasFix(
        DartFixKind.CHANGE_TO,
        '''
class MyClass {}
main() {
  MyClass v = null;
}
''');
  }

  void test_undefinedFunction_create_dynamicArgument() {
    resolveTestUnit('''
main() {
  dynamic v;
  test(v);
}
''');
    assertHasFix(
        DartFixKind.CREATE_FUNCTION,
        '''
main() {
  dynamic v;
  test(v);
}

void test(v) {
}
''');
  }

  void test_undefinedFunction_create_dynamicReturnType() {
    resolveTestUnit('''
main() {
  dynamic v = test();
}
''');
    assertHasFix(
        DartFixKind.CREATE_FUNCTION,
        '''
main() {
  dynamic v = test();
}

test() {
}
''');
  }

  void test_undefinedFunction_create_fromFunction() {
    resolveTestUnit('''
main() {
  int v = myUndefinedFunction(1, 2.0, '3');
}
''');
    assertHasFix(
        DartFixKind.CREATE_FUNCTION,
        '''
main() {
  int v = myUndefinedFunction(1, 2.0, '3');
}

int myUndefinedFunction(int i, double d, String s) {
}
''');
  }

  void test_undefinedFunction_create_fromMethod() {
    resolveTestUnit('''
class A {
  main() {
    int v = myUndefinedFunction(1, 2.0, '3');
  }
}
''');
    assertHasFix(
        DartFixKind.CREATE_FUNCTION,
        '''
class A {
  main() {
    int v = myUndefinedFunction(1, 2.0, '3');
  }
}

int myUndefinedFunction(int i, double d, String s) {
}
''');
  }

  void test_undefinedFunction_create_generic_BAD() {
    resolveTestUnit('''
class A<T> {
  Map<int, T> items;
  main() {
    process(items);
  }
}
''');
    assertHasFix(
        DartFixKind.CREATE_FUNCTION,
        '''
class A<T> {
  Map<int, T> items;
  main() {
    process(items);
  }
}

void process(Map items) {
}
''');
  }

  void test_undefinedFunction_create_generic_OK() {
    resolveTestUnit('''
class A {
  List<int> items;
  main() {
    process(items);
  }
}
''');
    assertHasFix(
        DartFixKind.CREATE_FUNCTION,
        '''
class A {
  List<int> items;
  main() {
    process(items);
  }
}

void process(List<int> items) {
}
''');
  }

  void test_undefinedFunction_create_importType() {
    addSource(
        '/lib.dart',
        r'''
library lib;
import 'dart:async';
Future getFuture() => null;
''');
    resolveTestUnit('''
import 'lib.dart';
main() {
  test(getFuture());
}
''');
    assertHasFix(
        DartFixKind.CREATE_FUNCTION,
        '''
import 'lib.dart';
import 'dart:async';
main() {
  test(getFuture());
}

void test(Future future) {
}
''');
  }

  void test_undefinedFunction_create_nullArgument() {
    resolveTestUnit('''
main() {
  test(null);
}
''');
    assertHasFix(
        DartFixKind.CREATE_FUNCTION,
        '''
main() {
  test(null);
}

void test(arg0) {
}
''');
  }

  void test_undefinedFunction_create_returnType_bool_expressions() {
    assert_undefinedFunction_create_returnType_bool("!test();");
    assert_undefinedFunction_create_returnType_bool("b && test();");
    assert_undefinedFunction_create_returnType_bool("test() && b;");
    assert_undefinedFunction_create_returnType_bool("b || test();");
    assert_undefinedFunction_create_returnType_bool("test() || b;");
  }

  void test_undefinedFunction_create_returnType_bool_statements() {
    assert_undefinedFunction_create_returnType_bool("assert ( test() );");
    assert_undefinedFunction_create_returnType_bool("if ( test() ) {}");
    assert_undefinedFunction_create_returnType_bool("while ( test() ) {}");
    assert_undefinedFunction_create_returnType_bool("do {} while ( test() );");
  }

  void test_undefinedFunction_create_returnType_fromAssignment_eq() {
    resolveTestUnit('''
main() {
  int v;
  v = myUndefinedFunction();
}
''');
    assertHasFix(
        DartFixKind.CREATE_FUNCTION,
        '''
main() {
  int v;
  v = myUndefinedFunction();
}

int myUndefinedFunction() {
}
''');
  }

  void test_undefinedFunction_create_returnType_fromAssignment_plusEq() {
    resolveTestUnit('''
main() {
  int v;
  v += myUndefinedFunction();
}
''');
    assertHasFix(
        DartFixKind.CREATE_FUNCTION,
        '''
main() {
  int v;
  v += myUndefinedFunction();
}

num myUndefinedFunction() {
}
''');
  }

  void test_undefinedFunction_create_returnType_fromBinary_right() {
    resolveTestUnit('''
main() {
  0 + myUndefinedFunction();
}
''');
    assertHasFix(
        DartFixKind.CREATE_FUNCTION,
        '''
main() {
  0 + myUndefinedFunction();
}

num myUndefinedFunction() {
}
''');
  }

  void test_undefinedFunction_create_returnType_fromInitializer() {
    resolveTestUnit('''
main() {
  int v = myUndefinedFunction();
}
''');
    assertHasFix(
        DartFixKind.CREATE_FUNCTION,
        '''
main() {
  int v = myUndefinedFunction();
}

int myUndefinedFunction() {
}
''');
  }

  void test_undefinedFunction_create_returnType_fromInvocationArgument() {
    resolveTestUnit('''
foo(int p) {}
main() {
  foo( myUndefinedFunction() );
}
''');
    assertHasFix(
        DartFixKind.CREATE_FUNCTION,
        '''
foo(int p) {}
main() {
  foo( myUndefinedFunction() );
}

int myUndefinedFunction() {
}
''');
  }

  void test_undefinedFunction_create_returnType_fromReturn() {
    resolveTestUnit('''
int main() {
  return myUndefinedFunction();
}
''');
    assertHasFix(
        DartFixKind.CREATE_FUNCTION,
        '''
int main() {
  return myUndefinedFunction();
}

int myUndefinedFunction() {
}
''');
  }

  void test_undefinedFunction_create_returnType_void() {
    resolveTestUnit('''
main() {
  myUndefinedFunction();
}
''');
    assertHasFix(
        DartFixKind.CREATE_FUNCTION,
        '''
main() {
  myUndefinedFunction();
}

void myUndefinedFunction() {
}
''');
  }

  void test_undefinedFunction_useSimilar_fromImport() {
    resolveTestUnit('''
main() {
  pritn(0);
}
''');
    assertHasFix(
        DartFixKind.CHANGE_TO,
        '''
main() {
  print(0);
}
''');
  }

  void test_undefinedFunction_useSimilar_thisLibrary() {
    resolveTestUnit('''
myFunction() {}
main() {
  myFuntcion();
}
''');
    assertHasFix(
        DartFixKind.CHANGE_TO,
        '''
myFunction() {}
main() {
  myFunction();
}
''');
  }

  void test_undefinedGetter_useSimilar_hint() {
    resolveTestUnit('''
class A {
  int myField;
}
main(A a) {
  var x = a;
  print(x.myFild);
}
''');
    assertHasFix(
        DartFixKind.CHANGE_TO,
        '''
class A {
  int myField;
}
main(A a) {
  var x = a;
  print(x.myField);
}
''');
  }

  void test_undefinedGetter_useSimilar_qualified() {
    resolveTestUnit('''
class A {
  int myField;
}
main(A a) {
  print(a.myFild);
}
''');
    assertHasFix(
        DartFixKind.CHANGE_TO,
        '''
class A {
  int myField;
}
main(A a) {
  print(a.myField);
}
''');
  }

  void test_undefinedGetter_useSimilar_qualified_static() {
    resolveTestUnit('''
class A {
  static int MY_NAME = 1;
}
main() {
  A.MY_NAM;
}
''');
    assertHasFix(
        DartFixKind.CHANGE_TO,
        '''
class A {
  static int MY_NAME = 1;
}
main() {
  A.MY_NAME;
}
''');
  }

  void test_undefinedGetter_useSimilar_unqualified() {
    resolveTestUnit('''
class A {
  int myField;
  main() {
    print(myFild);
  }
}
''');
    assertHasFix(
        DartFixKind.CHANGE_TO,
        '''
class A {
  int myField;
  main() {
    print(myField);
  }
}
''');
  }

  void test_undefinedMethod_create_BAD_inSDK() {
    resolveTestUnit('''
main() {
  List.foo();
}
''');
    assertNoFix(DartFixKind.CREATE_METHOD);
  }

  void test_undefinedMethod_create_generic_BAD_argumentType() {
    resolveTestUnit('''
class A<T> {
  B b;
  Map<int, T> items;
  main() {
    b.process(items);
  }
}

class B {
}
''');
    assertHasFix(
        DartFixKind.CREATE_METHOD,
        '''
class A<T> {
  B b;
  Map<int, T> items;
  main() {
    b.process(items);
  }
}

class B {
  void process(Map items) {
  }
}
''');
  }

  void test_undefinedMethod_create_generic_BAD_returnType() {
    resolveTestUnit('''
class A<T> {
  main() {
    T t = new B().compute();
  }
}

class B {
}
''');
    assertHasFix(
        DartFixKind.CREATE_METHOD,
        '''
class A<T> {
  main() {
    T t = new B().compute();
  }
}

class B {
  dynamic compute() {
  }
}
''');
  }

  void test_undefinedMethod_create_generic_OK_literal() {
    resolveTestUnit('''
class A {
  B b;
  List<int> items;
  main() {
    b.process(items);
  }
}

class B {
}
''');
    assertHasFix(
        DartFixKind.CREATE_METHOD,
        '''
class A {
  B b;
  List<int> items;
  main() {
    b.process(items);
  }
}

class B {
  void process(List<int> items) {
  }
}
''');
  }

  void test_undefinedMethod_create_generic_OK_local() {
    resolveTestUnit('''
class A<T> {
  List<T> items;
  main() {
    process(items);
  }
}
''');
    assertHasFix(
        DartFixKind.CREATE_METHOD,
        '''
class A<T> {
  List<T> items;
  main() {
    process(items);
  }

  void process(List<T> items) {
  }
}
''');
  }

  void test_undefinedMethod_createQualified_fromClass() {
    resolveTestUnit('''
class A {
}
main() {
  A.myUndefinedMethod();
}
''');
    assertHasFix(
        DartFixKind.CREATE_METHOD,
        '''
class A {
  static void myUndefinedMethod() {
  }
}
main() {
  A.myUndefinedMethod();
}
''');
  }

  void test_undefinedMethod_createQualified_fromClass_hasOtherMember() {
    resolveTestUnit('''
class A {
  foo() {}
}
main() {
  A.myUndefinedMethod();
}
''');
    assertHasFix(
        DartFixKind.CREATE_METHOD,
        '''
class A {
  foo() {}

  static void myUndefinedMethod() {
  }
}
main() {
  A.myUndefinedMethod();
}
''');
  }

  void test_undefinedMethod_createQualified_fromInstance() {
    resolveTestUnit('''
class A {
}
main(A a) {
  a.myUndefinedMethod();
}
''');
    assertHasFix(
        DartFixKind.CREATE_METHOD,
        '''
class A {
  void myUndefinedMethod() {
  }
}
main(A a) {
  a.myUndefinedMethod();
}
''');
  }

  void test_undefinedMethod_createQualified_targetIsFunctionType() {
    resolveTestUnit('''
typedef A();
main() {
  A.myUndefinedMethod();
}
''');
    assertNoFix(DartFixKind.CREATE_METHOD);
  }

  void test_undefinedMethod_createQualified_targetIsUnresolved() {
    resolveTestUnit('''
main() {
  NoSuchClass.myUndefinedMethod();
}
''');
    assertNoFix(DartFixKind.CREATE_METHOD);
  }

  void test_undefinedMethod_createUnqualified_parameters() {
    resolveTestUnit('''
class A {
  main() {
    myUndefinedMethod(0, 1.0, '3');
  }
}
''');
    assertHasFix(
        DartFixKind.CREATE_METHOD,
        '''
class A {
  main() {
    myUndefinedMethod(0, 1.0, '3');
  }

  void myUndefinedMethod(int i, double d, String s) {
  }
}
''');
    // linked positions
    int index = 0;
    _assertLinkedGroup(
        change.linkedEditGroups[index++], ['void myUndefinedMethod(']);
    _assertLinkedGroup(change.linkedEditGroups[index++],
        ['myUndefinedMethod(0', 'myUndefinedMethod(int']);
    _assertLinkedGroup(
        change.linkedEditGroups[index++],
        ['int i'],
        expectedSuggestions(LinkedEditSuggestionKind.TYPE,
            ['int', 'num', 'Object', 'Comparable']));
    _assertLinkedGroup(change.linkedEditGroups[index++], ['i,']);
    _assertLinkedGroup(
        change.linkedEditGroups[index++],
        ['double d'],
        expectedSuggestions(LinkedEditSuggestionKind.TYPE,
            ['double', 'num', 'Object', 'Comparable']));
    _assertLinkedGroup(change.linkedEditGroups[index++], ['d,']);
    _assertLinkedGroup(
        change.linkedEditGroups[index++],
        ['String s'],
        expectedSuggestions(
            LinkedEditSuggestionKind.TYPE, ['String', 'Object', 'Comparable']));
    _assertLinkedGroup(change.linkedEditGroups[index++], ['s)']);
  }

  void test_undefinedMethod_createUnqualified_returnType() {
    resolveTestUnit('''
class A {
  main() {
    int v = myUndefinedMethod();
  }
}
''');
    assertHasFix(
        DartFixKind.CREATE_METHOD,
        '''
class A {
  main() {
    int v = myUndefinedMethod();
  }

  int myUndefinedMethod() {
  }
}
''');
    // linked positions
    _assertLinkedGroup(change.linkedEditGroups[0], ['int myUndefinedMethod(']);
    _assertLinkedGroup(change.linkedEditGroups[1],
        ['myUndefinedMethod();', 'myUndefinedMethod() {']);
  }

  void test_undefinedMethod_createUnqualified_staticFromField() {
    resolveTestUnit('''
class A {
  static var f = myUndefinedMethod();
}
''');
    assertHasFix(
        DartFixKind.CREATE_METHOD,
        '''
class A {
  static var f = myUndefinedMethod();

  static myUndefinedMethod() {
  }
}
''');
  }

  void test_undefinedMethod_createUnqualified_staticFromMethod() {
    resolveTestUnit('''
class A {
  static main() {
    myUndefinedMethod();
  }
}
''');
    assertHasFix(
        DartFixKind.CREATE_METHOD,
        '''
class A {
  static main() {
    myUndefinedMethod();
  }

  static void myUndefinedMethod() {
  }
}
''');
  }

  void test_undefinedMethod_hint_createQualified_fromInstance() {
    resolveTestUnit('''
class A {
}
main() {
  var a = new A();
  a.myUndefinedMethod();
}
''');
    assertHasFix(
        DartFixKind.CREATE_METHOD,
        '''
class A {
  void myUndefinedMethod() {
  }
}
main() {
  var a = new A();
  a.myUndefinedMethod();
}
''');
  }

  void test_undefinedMethod_parameterType_differentPrefixInTargetUnit() {
    String code2 = r'''
library test2;
import 'test3.dart' as bbb;
export 'test3.dart';
class D {
}
''';
    addSource('/test2.dart', code2);
    addSource(
        '/test3.dart',
        r'''
library test3;
class E {}
''');
    resolveTestUnit('''
library test;
import 'test2.dart' as aaa;
main(aaa.D d, aaa.E e) {
  d.foo(e);
}
''');
    AnalysisError error = _findErrorToFix();
    fix = _assertHasFix(DartFixKind.CREATE_METHOD, error);
    change = fix.change;
    // apply to "test2.dart"
    List<SourceFileEdit> fileEdits = change.edits;
    expect(fileEdits, hasLength(1));
    SourceFileEdit fileEdit = change.edits[0];
    expect(fileEdit.file, '/test2.dart');
    expect(
        SourceEdit.applySequence(code2, fileEdit.edits),
        r'''
library test2;
import 'test3.dart' as bbb;
export 'test3.dart';
class D {
  void foo(bbb.E e) {
  }
}
''');
  }

  void test_undefinedMethod_parameterType_inTargetUnit() {
    String code2 = r'''
library test2;
class D {
}
class E {}
''';
    addSource('/test2.dart', code2);
    resolveTestUnit('''
library test;
import 'test2.dart' as test2;
main(test2.D d, test2.E e) {
  d.foo(e);
}
''');
    AnalysisError error = _findErrorToFix();
    fix = _assertHasFix(DartFixKind.CREATE_METHOD, error);
    change = fix.change;
    // apply to "test2.dart"
    List<SourceFileEdit> fileEdits = change.edits;
    expect(fileEdits, hasLength(1));
    SourceFileEdit fileEdit = change.edits[0];
    expect(fileEdit.file, '/test2.dart');
    expect(
        SourceEdit.applySequence(code2, fileEdit.edits),
        r'''
library test2;
class D {
  void foo(E e) {
  }
}
class E {}
''');
  }

  void test_undefinedMethod_useSimilar_ignoreOperators() {
    resolveTestUnit('''
main(Object object) {
  object.then();
}
''');
    assertNoFix(DartFixKind.CHANGE_TO);
  }

  void test_undefinedMethod_useSimilar_qualified() {
    resolveTestUnit('''
class A {
  myMethod() {}
}
main() {
  A a = new A();
  a.myMehtod();
}
''');
    assertHasFix(
        DartFixKind.CHANGE_TO,
        '''
class A {
  myMethod() {}
}
main() {
  A a = new A();
  a.myMethod();
}
''');
  }

  void test_undefinedMethod_useSimilar_unqualified_superClass() {
    resolveTestUnit('''
class A {
  myMethod() {}
}
class B extends A {
  main() {
    myMehtod();
  }
}
''');
    assertHasFix(
        DartFixKind.CHANGE_TO,
        '''
class A {
  myMethod() {}
}
class B extends A {
  main() {
    myMethod();
  }
}
''');
  }

  void test_undefinedMethod_useSimilar_unqualified_thisClass() {
    resolveTestUnit('''
class A {
  myMethod() {}
  main() {
    myMehtod();
  }
}
''');
    assertHasFix(
        DartFixKind.CHANGE_TO,
        '''
class A {
  myMethod() {}
  main() {
    myMethod();
  }
}
''');
  }

  void test_undefinedSetter_useSimilar_hint() {
    resolveTestUnit('''
class A {
  int myField;
}
main(A a) {
  var x = a;
  x.myFild = 42;
}
''');
    assertHasFix(
        DartFixKind.CHANGE_TO,
        '''
class A {
  int myField;
}
main(A a) {
  var x = a;
  x.myField = 42;
}
''');
  }

  void test_undefinedSetter_useSimilar_qualified() {
    resolveTestUnit('''
class A {
  int myField;
}
main(A a) {
  a.myFild = 42;
}
''');
    assertHasFix(
        DartFixKind.CHANGE_TO,
        '''
class A {
  int myField;
}
main(A a) {
  a.myField = 42;
}
''');
  }

  void test_undefinedSetter_useSimilar_unqualified() {
    resolveTestUnit('''
class A {
  int myField;
  main() {
    myFild = 42;
  }
}
''');
    assertHasFix(
        DartFixKind.CHANGE_TO,
        '''
class A {
  int myField;
  main() {
    myField = 42;
  }
}
''');
  }

  void test_useEffectiveIntegerDivision() {
    resolveTestUnit('''
main() {
  var a = 5;
  var b = 2;
  print((a / b).toInt());
}
''');
    assertHasFix(
        DartFixKind.USE_EFFECTIVE_INTEGER_DIVISION,
        '''
main() {
  var a = 5;
  var b = 2;
  print(a ~/ b);
}
''');
  }

  void test_useImportPrefix_withClass() {
    resolveTestUnit('''
import 'dart:async' as pref;
main() {
  pref.Stream s = null;
  Future f = null;
}
''');
    assertHasFix(
        DartFixKind.IMPORT_LIBRARY_PREFIX,
        '''
import 'dart:async' as pref;
main() {
  pref.Stream s = null;
  pref.Future f = null;
}
''');
  }

  void test_useImportPrefix_withTopLevelVariable() {
    resolveTestUnit('''
import 'dart:math' as pref;
main() {
  print(pref.E);
  print(PI);
}
''');
    assertHasFix(
        DartFixKind.IMPORT_LIBRARY_PREFIX,
        '''
import 'dart:math' as pref;
main() {
  print(pref.E);
  print(pref.PI);
}
''');
  }

  /**
   * Computes fixes and verifies that there is a fix of the given kind.
   */
  Fix _assertHasFix(FixKind kind, AnalysisError error) {
    List<Fix> fixes = _computeFixes(error);
    for (Fix fix in fixes) {
      if (fix.kind == kind) {
        return fix;
      }
    }
    throw fail('Expected to find fix $kind in\n${fixes.join('\n')}');
  }

  void _assertLinkedGroup(LinkedEditGroup group, List<String> expectedStrings,
      [List<LinkedEditSuggestion> expectedSuggestions]) {
    List<Position> expectedPositions = _findResultPositions(expectedStrings);
    expect(group.positions, unorderedEquals(expectedPositions));
    if (expectedSuggestions != null) {
      expect(group.suggestions, unorderedEquals(expectedSuggestions));
    }
  }

  /**
   * Computes fixes for the given [error] in [testUnit].
   */
  List<Fix> _computeFixes(AnalysisError error) {
    FixProcessor processor = new FixProcessor(provider, testUnit, error);
    return processor.compute();
  }

  /**
   * Configures the [SourceFactory] to have the `my_pkg` package in
   * `/packages/my_pkg/lib` folder.
   */
  void _configureMyPkg(String myLibCode) {
    provider.newFile('/packages/my_pkg/lib/my_lib.dart', myLibCode);
    // configure SourceFactory
    Folder myPkgFolder = provider.getResource('/packages/my_pkg/lib');
    UriResolver pkgResolver = new PackageMapUriResolver(provider, {
      'my_pkg': [myPkgFolder]
    });
    context.sourceFactory = new SourceFactory(
        [AbstractContextTest.SDK_RESOLVER, pkgResolver, resourceResolver]);
    // force 'my_pkg' resolution
    addSource('/tmp/other.dart', "import 'package:my_pkg/my_lib.dart';");
  }

  AnalysisError _findErrorToFix() {
    List<AnalysisError> errors = context.computeErrors(testSource);
    if (errorFilter != null) {
      errors = errors.where(errorFilter).toList();
    }
    expect(errors, hasLength(1));
    return errors[0];
  }

  List<Position> _findResultPositions(List<String> searchStrings) {
    List<Position> positions = <Position>[];
    for (String search in searchStrings) {
      int offset = resultCode.indexOf(search);
      positions.add(new Position(testFile, offset));
    }
    return positions;
  }

  void _performAnalysis() {
    while (context.performAnalysisTask().hasMoreWork);
  }
}
