// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of _interceptors;

/**
 * The interceptor class for [String]. The compiler recognizes this
 * class as an interceptor, and changes references to [:this:] to
 * actually use the receiver of the method, which is generated as an extra
 * argument added to each member.
 */
class JSString implements String {
  const JSString();

  int charCodeAt(index) {
    if (index is !num) throw new ArgumentError(index);
    if (index < 0) throw new RangeError.value(index);
    if (index >= length) throw new RangeError.value(index);
    return JS('int', r'#.charCodeAt(#)', this, index);
  }

  Iterable<Match> allMatches(String str) {
    checkString(str);
    return allMatchesInStringUnchecked(this, str);
  }

  String concat(String other) {
    if (other is !String) throw new ArgumentError(other);
    return JS('String', r'# + #', this, other);
  }

  bool endsWith(String other) {
    checkString(other);
    int otherLength = other.length;
    if (otherLength > length) return false;
    return other == substring(length - otherLength);
  }

  String replaceAll(Pattern from, String to) {
    checkString(to);
    return stringReplaceAllUnchecked(this, from, to);
  }

  String replaceFirst(Pattern from, String to) {
    checkString(to);
    return stringReplaceFirstUnchecked(this, from, to);
  }

  List<String> split(Pattern pattern) {
    checkNull(pattern);
    return stringSplitUnchecked(this, pattern);
  }

  List<String> splitChars() {
    return JS('List', r'#.split("")', this);
  }

  bool startsWith(String other) {
    checkString(other);
    int otherLength = other.length;
    if (otherLength > length) return false;
    return JS('bool', r'# == #', other,
              JS('String', r'#.substring(0, #)', this, otherLength));
  }

  String substring(int startIndex, [int endIndex]) {
    checkNum(startIndex);
    if (endIndex == null) endIndex = length;
    checkNum(endIndex);
    if (startIndex < 0 ) throw new RangeError.value(startIndex);
    if (startIndex > endIndex) throw new RangeError.value(startIndex);
    if (endIndex > length) throw new RangeError.value(endIndex);
    return JS('String', r'#.substring(#, #)', this, startIndex, endIndex);
  }

  String toLowerCase() {
    return JS('String', r'#.toLowerCase()', this);
  }

  String toUpperCase() {
    return JS('String', r'#.toUpperCase()', this);
  }

  String trim() {
    return JS('String', r'#.trim()', this);
  }

  List<int> get charCodes  {
    List<int> result = new List<int>(length);
    for (int i = 0; i < length; i++) {
      result[i] = charCodeAt(i);
    }
    return result;
  }
}