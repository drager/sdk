library pub_upgrade_test;
import 'dart:async';
import 'package:unittest/unittest.dart';
import '../lib/src/lock_file.dart';
import '../lib/src/log.dart' as log;
import '../lib/src/package.dart';
import '../lib/src/pubspec.dart';
import '../lib/src/sdk.dart' as sdk;
import '../lib/src/source/cached.dart';
import '../lib/src/system_cache.dart';
import '../lib/src/utils.dart';
import '../lib/src/version.dart';
import '../lib/src/solver/version_solver.dart';
import 'test_pub.dart';
MockSource source1;
MockSource source2;
main() {
  initConfig();
  sdk.version = new Version(1, 2, 3);
  group('basic graph', basicGraph);
  group('with lockfile', withLockFile);
  group('root dependency', rootDependency);
  group('dev dependency', devDependency);
  group('unsolvable', unsolvable);
  group('bad source', badSource);
  group('backtracking', backtracking);
  group('SDK constraint', sdkConstraint);
  group('pre-release', prerelease);
  group('override', override);
  group('downgrade', downgrade);
}
void basicGraph() {
  testResolve('no dependencies', {
    'myapp 0.0.0': {}
  }, result: {
    'myapp from root': '0.0.0'
  });
  testResolve('simple dependency tree', {
    'myapp 0.0.0': {
      'a': '1.0.0',
      'b': '1.0.0'
    },
    'a 1.0.0': {
      'aa': '1.0.0',
      'ab': '1.0.0'
    },
    'aa 1.0.0': {},
    'ab 1.0.0': {},
    'b 1.0.0': {
      'ba': '1.0.0',
      'bb': '1.0.0'
    },
    'ba 1.0.0': {},
    'bb 1.0.0': {}
  }, result: {
    'myapp from root': '0.0.0',
    'a': '1.0.0',
    'aa': '1.0.0',
    'ab': '1.0.0',
    'b': '1.0.0',
    'ba': '1.0.0',
    'bb': '1.0.0'
  });
  testResolve('shared dependency with overlapping constraints', {
    'myapp 0.0.0': {
      'a': '1.0.0',
      'b': '1.0.0'
    },
    'a 1.0.0': {
      'shared': '>=2.0.0 <4.0.0'
    },
    'b 1.0.0': {
      'shared': '>=3.0.0 <5.0.0'
    },
    'shared 2.0.0': {},
    'shared 3.0.0': {},
    'shared 3.6.9': {},
    'shared 4.0.0': {},
    'shared 5.0.0': {}
  }, result: {
    'myapp from root': '0.0.0',
    'a': '1.0.0',
    'b': '1.0.0',
    'shared': '3.6.9'
  });
  testResolve(
      'shared dependency where dependent version in turn affects '
          'other dependencies',
      {
    'myapp 0.0.0': {
      'foo': '<=1.0.2',
      'bar': '1.0.0'
    },
    'foo 1.0.0': {},
    'foo 1.0.1': {
      'bang': '1.0.0'
    },
    'foo 1.0.2': {
      'whoop': '1.0.0'
    },
    'foo 1.0.3': {
      'zoop': '1.0.0'
    },
    'bar 1.0.0': {
      'foo': '<=1.0.1'
    },
    'bang 1.0.0': {},
    'whoop 1.0.0': {},
    'zoop 1.0.0': {}
  }, result: {
    'myapp from root': '0.0.0',
    'foo': '1.0.1',
    'bar': '1.0.0',
    'bang': '1.0.0'
  }, maxTries: 2);
  testResolve('circular dependency', {
    'myapp 1.0.0': {
      'foo': '1.0.0'
    },
    'foo 1.0.0': {
      'bar': '1.0.0'
    },
    'bar 1.0.0': {
      'foo': '1.0.0'
    }
  }, result: {
    'myapp from root': '1.0.0',
    'foo': '1.0.0',
    'bar': '1.0.0'
  });
}
withLockFile() {
  testResolve('with compatible locked dependency', {
    'myapp 0.0.0': {
      'foo': 'any'
    },
    'foo 1.0.0': {
      'bar': '1.0.0'
    },
    'foo 1.0.1': {
      'bar': '1.0.1'
    },
    'foo 1.0.2': {
      'bar': '1.0.2'
    },
    'bar 1.0.0': {},
    'bar 1.0.1': {},
    'bar 1.0.2': {}
  }, lockfile: {
    'foo': '1.0.1'
  }, result: {
    'myapp from root': '0.0.0',
    'foo': '1.0.1',
    'bar': '1.0.1'
  });
  testResolve('with incompatible locked dependency', {
    'myapp 0.0.0': {
      'foo': '>1.0.1'
    },
    'foo 1.0.0': {
      'bar': '1.0.0'
    },
    'foo 1.0.1': {
      'bar': '1.0.1'
    },
    'foo 1.0.2': {
      'bar': '1.0.2'
    },
    'bar 1.0.0': {},
    'bar 1.0.1': {},
    'bar 1.0.2': {}
  }, lockfile: {
    'foo': '1.0.1'
  }, result: {
    'myapp from root': '0.0.0',
    'foo': '1.0.2',
    'bar': '1.0.2'
  });
  testResolve('with unrelated locked dependency', {
    'myapp 0.0.0': {
      'foo': 'any'
    },
    'foo 1.0.0': {
      'bar': '1.0.0'
    },
    'foo 1.0.1': {
      'bar': '1.0.1'
    },
    'foo 1.0.2': {
      'bar': '1.0.2'
    },
    'bar 1.0.0': {},
    'bar 1.0.1': {},
    'bar 1.0.2': {},
    'baz 1.0.0': {}
  }, lockfile: {
    'baz': '1.0.0'
  }, result: {
    'myapp from root': '0.0.0',
    'foo': '1.0.2',
    'bar': '1.0.2'
  });
  testResolve(
      'unlocks dependencies if necessary to ensure that a new '
          'dependency is satisfied',
      {
    'myapp 0.0.0': {
      'foo': 'any',
      'newdep': 'any'
    },
    'foo 1.0.0': {
      'bar': '<2.0.0'
    },
    'bar 1.0.0': {
      'baz': '<2.0.0'
    },
    'baz 1.0.0': {
      'qux': '<2.0.0'
    },
    'qux 1.0.0': {},
    'foo 2.0.0': {
      'bar': '<3.0.0'
    },
    'bar 2.0.0': {
      'baz': '<3.0.0'
    },
    'baz 2.0.0': {
      'qux': '<3.0.0'
    },
    'qux 2.0.0': {},
    'newdep 2.0.0': {
      'baz': '>=1.5.0'
    }
  }, lockfile: {
    'foo': '1.0.0',
    'bar': '1.0.0',
    'baz': '1.0.0',
    'qux': '1.0.0'
  }, result: {
    'myapp from root': '0.0.0',
    'foo': '2.0.0',
    'bar': '2.0.0',
    'baz': '2.0.0',
    'qux': '1.0.0',
    'newdep': '2.0.0'
  }, maxTries: 3);
}
rootDependency() {
  testResolve('with root source', {
    'myapp 1.0.0': {
      'foo': '1.0.0'
    },
    'foo 1.0.0': {
      'myapp from root': '>=1.0.0'
    }
  }, result: {
    'myapp from root': '1.0.0',
    'foo': '1.0.0'
  });
  testResolve('with different source', {
    'myapp 1.0.0': {
      'foo': '1.0.0'
    },
    'foo 1.0.0': {
      'myapp': '>=1.0.0'
    }
  }, result: {
    'myapp from root': '1.0.0',
    'foo': '1.0.0'
  });
  testResolve('with mismatched sources', {
    'myapp 1.0.0': {
      'foo': '1.0.0',
      'bar': '1.0.0'
    },
    'foo 1.0.0': {
      'myapp': '>=1.0.0'
    },
    'bar 1.0.0': {
      'myapp from mock2': '>=1.0.0'
    }
  }, error: sourceMismatch('myapp', 'foo', 'bar'));
  testResolve('with wrong version', {
    'myapp 1.0.0': {
      'foo': '1.0.0'
    },
    'foo 1.0.0': {
      'myapp': '<1.0.0'
    }
  }, error: couldNotSolve);
}
devDependency() {
  testResolve("includes root package's dev dependencies", {
    'myapp 1.0.0': {
      '(dev) foo': '1.0.0',
      '(dev) bar': '1.0.0'
    },
    'foo 1.0.0': {},
    'bar 1.0.0': {}
  }, result: {
    'myapp from root': '1.0.0',
    'foo': '1.0.0',
    'bar': '1.0.0'
  });
  testResolve("includes dev dependency's transitive dependencies", {
    'myapp 1.0.0': {
      '(dev) foo': '1.0.0'
    },
    'foo 1.0.0': {
      'bar': '1.0.0'
    },
    'bar 1.0.0': {}
  }, result: {
    'myapp from root': '1.0.0',
    'foo': '1.0.0',
    'bar': '1.0.0'
  });
  testResolve("ignores transitive dependency's dev dependencies", {
    'myapp 1.0.0': {
      'foo': '1.0.0'
    },
    'foo 1.0.0': {
      '(dev) bar': '1.0.0'
    },
    'bar 1.0.0': {}
  }, result: {
    'myapp from root': '1.0.0',
    'foo': '1.0.0'
  });
}
unsolvable() {
  testResolve('no version that matches requirement', {
    'myapp 0.0.0': {
      'foo': '>=1.0.0 <2.0.0'
    },
    'foo 2.0.0': {},
    'foo 2.1.3': {}
  }, error: noVersion(['myapp', 'foo']));
  testResolve('no version that matches combined constraint', {
    'myapp 0.0.0': {
      'foo': '1.0.0',
      'bar': '1.0.0'
    },
    'foo 1.0.0': {
      'shared': '>=2.0.0 <3.0.0'
    },
    'bar 1.0.0': {
      'shared': '>=2.9.0 <4.0.0'
    },
    'shared 2.5.0': {},
    'shared 3.5.0': {}
  }, error: noVersion(['shared', 'foo', 'bar']));
  testResolve('disjoint constraints', {
    'myapp 0.0.0': {
      'foo': '1.0.0',
      'bar': '1.0.0'
    },
    'foo 1.0.0': {
      'shared': '<=2.0.0'
    },
    'bar 1.0.0': {
      'shared': '>3.0.0'
    },
    'shared 2.0.0': {},
    'shared 4.0.0': {}
  }, error: disjointConstraint(['shared', 'foo', 'bar']));
  testResolve('mismatched descriptions', {
    'myapp 0.0.0': {
      'foo': '1.0.0',
      'bar': '1.0.0'
    },
    'foo 1.0.0': {
      'shared-x': '1.0.0'
    },
    'bar 1.0.0': {
      'shared-y': '1.0.0'
    },
    'shared-x 1.0.0': {},
    'shared-y 1.0.0': {}
  }, error: descriptionMismatch('shared', 'foo', 'bar'));
  testResolve('mismatched sources', {
    'myapp 0.0.0': {
      'foo': '1.0.0',
      'bar': '1.0.0'
    },
    'foo 1.0.0': {
      'shared': '1.0.0'
    },
    'bar 1.0.0': {
      'shared from mock2': '1.0.0'
    },
    'shared 1.0.0': {},
    'shared 1.0.0 from mock2': {}
  }, error: sourceMismatch('shared', 'foo', 'bar'));
  testResolve('no valid solution', {
    'myapp 0.0.0': {
      'a': 'any',
      'b': 'any'
    },
    'a 1.0.0': {
      'b': '1.0.0'
    },
    'a 2.0.0': {
      'b': '2.0.0'
    },
    'b 1.0.0': {
      'a': '2.0.0'
    },
    'b 2.0.0': {
      'a': '1.0.0'
    }
  }, error: couldNotSolve, maxTries: 4);
  testResolve('no version that matches while backtracking', {
    'myapp 0.0.0': {
      'a': 'any',
      'b': '>1.0.0'
    },
    'a 1.0.0': {},
    'b 1.0.0': {}
  }, error: noVersion(['myapp', 'b']), maxTries: 1);
  testResolve('...', {
    "myapp 0.0.0": {
      "angular": "any",
      "collection": "any"
    },
    "analyzer 0.12.2": {},
    "angular 0.10.0": {
      "di": ">=0.0.32 <0.1.0",
      "collection": ">=0.9.1 <1.0.0"
    },
    "angular 0.9.11": {
      "di": ">=0.0.32 <0.1.0",
      "collection": ">=0.9.1 <1.0.0"
    },
    "angular 0.9.10": {
      "di": ">=0.0.32 <0.1.0",
      "collection": ">=0.9.1 <1.0.0"
    },
    "collection 0.9.0": {},
    "collection 0.9.1": {},
    "di 0.0.37": {
      "analyzer": ">=0.13.0 <0.14.0"
    },
    "di 0.0.36": {
      "analyzer": ">=0.13.0 <0.14.0"
    }
  }, error: noVersion(['myapp', 'angular', 'collection']), maxTries: 9);
}
badSource() {
  testResolve('fail if the root package has a bad source in dep', {
    'myapp 0.0.0': {
      'foo from bad': 'any'
    }
  }, error: unknownSource('myapp', 'foo', 'bad'));
  testResolve('fail if the root package has a bad source in dev dep', {
    'myapp 0.0.0': {
      '(dev) foo from bad': 'any'
    }
  }, error: unknownSource('myapp', 'foo', 'bad'));
  testResolve('fail if all versions have bad source in dep', {
    'myapp 0.0.0': {
      'foo': 'any'
    },
    'foo 1.0.0': {
      'bar from bad': 'any'
    },
    'foo 1.0.1': {
      'baz from bad': 'any'
    },
    'foo 1.0.3': {
      'bang from bad': 'any'
    }
  }, error: unknownSource('foo', 'bar', 'bad'), maxTries: 3);
  testResolve('ignore versions with bad source in dep', {
    'myapp 1.0.0': {
      'foo': 'any'
    },
    'foo 1.0.0': {
      'bar': 'any'
    },
    'foo 1.0.1': {
      'bar from bad': 'any'
    },
    'foo 1.0.3': {
      'bar from bad': 'any'
    },
    'bar 1.0.0': {}
  }, result: {
    'myapp from root': '1.0.0',
    'foo': '1.0.0',
    'bar': '1.0.0'
  }, maxTries: 3);
}
backtracking() {
  testResolve('circular dependency on older version', {
    'myapp 0.0.0': {
      'a': '>=1.0.0'
    },
    'a 1.0.0': {},
    'a 2.0.0': {
      'b': '1.0.0'
    },
    'b 1.0.0': {
      'a': '1.0.0'
    }
  }, result: {
    'myapp from root': '0.0.0',
    'a': '1.0.0'
  }, maxTries: 2);
  testResolve('rolls back leaf versions first', {
    'myapp 0.0.0': {
      'a': 'any'
    },
    'a 1.0.0': {
      'b': 'any'
    },
    'a 2.0.0': {
      'b': 'any',
      'c': '2.0.0'
    },
    'b 1.0.0': {},
    'b 2.0.0': {
      'c': '1.0.0'
    },
    'c 1.0.0': {},
    'c 2.0.0': {}
  }, result: {
    'myapp from root': '0.0.0',
    'a': '2.0.0',
    'b': '1.0.0',
    'c': '2.0.0'
  }, maxTries: 2);
  testResolve('simple transitive', {
    'myapp 0.0.0': {
      'foo': 'any'
    },
    'foo 1.0.0': {
      'bar': '1.0.0'
    },
    'foo 2.0.0': {
      'bar': '2.0.0'
    },
    'foo 3.0.0': {
      'bar': '3.0.0'
    },
    'bar 1.0.0': {
      'baz': 'any'
    },
    'bar 2.0.0': {
      'baz': '2.0.0'
    },
    'bar 3.0.0': {
      'baz': '3.0.0'
    },
    'baz 1.0.0': {}
  }, result: {
    'myapp from root': '0.0.0',
    'foo': '1.0.0',
    'bar': '1.0.0',
    'baz': '1.0.0'
  }, maxTries: 3);
  testResolve('backjump to nearer unsatisfied package', {
    'myapp 0.0.0': {
      'a': 'any',
      'b': 'any'
    },
    'a 1.0.0': {
      'c': '1.0.0'
    },
    'a 2.0.0': {
      'c': '2.0.0-nonexistent'
    },
    'b 1.0.0': {},
    'b 2.0.0': {},
    'b 3.0.0': {},
    'c 1.0.0': {}
  }, result: {
    'myapp from root': '0.0.0',
    'a': '1.0.0',
    'b': '3.0.0',
    'c': '1.0.0'
  }, maxTries: 2);
  testResolve('backjump to conflicting source', {
    'myapp 0.0.0': {
      'a': 'any',
      'b': 'any',
      'c': 'any'
    },
    'a 1.0.0': {},
    'a 1.0.0 from mock2': {},
    'b 1.0.0': {
      'a': 'any'
    },
    'b 2.0.0': {
      'a from mock2': 'any'
    },
    'c 1.0.0': {},
    'c 2.0.0': {},
    'c 3.0.0': {},
    'c 4.0.0': {},
    'c 5.0.0': {}
  }, result: {
    'myapp from root': '0.0.0',
    'a': '1.0.0',
    'b': '1.0.0',
    'c': '5.0.0'
  }, maxTries: 2);
  testResolve('backjump to conflicting description', {
    'myapp 0.0.0': {
      'a-x': 'any',
      'b': 'any',
      'c': 'any'
    },
    'a-x 1.0.0': {},
    'a-y 1.0.0': {},
    'b 1.0.0': {
      'a-x': 'any'
    },
    'b 2.0.0': {
      'a-y': 'any'
    },
    'c 1.0.0': {},
    'c 2.0.0': {},
    'c 3.0.0': {},
    'c 4.0.0': {},
    'c 5.0.0': {}
  }, result: {
    'myapp from root': '0.0.0',
    'a': '1.0.0',
    'b': '1.0.0',
    'c': '5.0.0'
  }, maxTries: 2);
  testResolve('backjump to conflicting source', {
    'myapp 0.0.0': {
      'a': 'any',
      'b': 'any',
      'c': 'any'
    },
    'a 1.0.0': {},
    'a 1.0.0 from mock2': {},
    'b 1.0.0': {
      'a from mock2': 'any'
    },
    'c 1.0.0': {},
    'c 2.0.0': {},
    'c 3.0.0': {},
    'c 4.0.0': {},
    'c 5.0.0': {}
  }, error: sourceMismatch('a', 'myapp', 'b'), maxTries: 1);
  testResolve('backjump to conflicting description', {
    'myapp 0.0.0': {
      'a-x': 'any',
      'b': 'any',
      'c': 'any'
    },
    'a-x 1.0.0': {},
    'a-y 1.0.0': {},
    'b 1.0.0': {
      'a-y': 'any'
    },
    'c 1.0.0': {},
    'c 2.0.0': {},
    'c 3.0.0': {},
    'c 4.0.0': {},
    'c 5.0.0': {}
  }, error: descriptionMismatch('a', 'myapp', 'b'), maxTries: 1);
  testResolve('traverse into package with fewer versions first', {
    'myapp 0.0.0': {
      'a': 'any',
      'b': 'any'
    },
    'a 1.0.0': {
      'c': 'any'
    },
    'a 2.0.0': {
      'c': 'any'
    },
    'a 3.0.0': {
      'c': 'any'
    },
    'a 4.0.0': {
      'c': 'any'
    },
    'a 5.0.0': {
      'c': '1.0.0'
    },
    'b 1.0.0': {
      'c': 'any'
    },
    'b 2.0.0': {
      'c': 'any'
    },
    'b 3.0.0': {
      'c': 'any'
    },
    'b 4.0.0': {
      'c': '2.0.0'
    },
    'c 1.0.0': {},
    'c 2.0.0': {}
  }, result: {
    'myapp from root': '0.0.0',
    'a': '4.0.0',
    'b': '4.0.0',
    'c': '2.0.0'
  }, maxTries: 2);
  testResolve('take root package constraints into counting versions', {
    "myapp 0.0.0": {
      "foo": ">2.0.0",
      "bar": "any"
    },
    "foo 1.0.0": {
      "none": "2.0.0"
    },
    "foo 2.0.0": {
      "none": "2.0.0"
    },
    "foo 3.0.0": {
      "none": "2.0.0"
    },
    "foo 4.0.0": {
      "none": "2.0.0"
    },
    "bar 1.0.0": {},
    "bar 2.0.0": {},
    "bar 3.0.0": {},
    "none 1.0.0": {}
  }, error: noVersion(["foo", "none"]), maxTries: 2);
  var map = {
    'myapp 0.0.0': {
      'foo': 'any',
      'bar': 'any'
    },
    'baz 0.0.0': {}
  };
  for (var i = 0; i < 10; i++) {
    for (var j = 0; j < 10; j++) {
      map['foo $i.$j.0'] = {
        'baz': '$i.0.0'
      };
      map['bar $i.$j.0'] = {
        'baz': '0.$j.0'
      };
    }
  }
  testResolve('complex backtrack', map, result: {
    'myapp from root': '0.0.0',
    'foo': '0.9.0',
    'bar': '9.0.0',
    'baz': '0.0.0'
  }, maxTries: 100);
  testResolve('backjump past failed package on disjoint constraint', {
    'myapp 0.0.0': {
      'a': 'any',
      'foo': '>2.0.0'
    },
    'a 1.0.0': {
      'foo': 'any'
    },
    'a 2.0.0': {
      'foo': '<1.0.0'
    },
    'foo 2.0.0': {},
    'foo 2.0.1': {},
    'foo 2.0.2': {},
    'foo 2.0.3': {},
    'foo 2.0.4': {}
  }, result: {
    'myapp from root': '0.0.0',
    'a': '1.0.0',
    'foo': '2.0.4'
  }, maxTries: 2);
  testResolve("finds solution with less strict constraint", {
    "myapp 1.0.0": {
      "a": "any",
      "c": "any",
      "d": "any"
    },
    "a 2.0.0": {},
    "a 1.0.0": {},
    "b 1.0.0": {
      "a": "1.0.0"
    },
    "c 1.0.0": {
      "b": "any"
    },
    "d 2.0.0": {
      "myapp": "any"
    },
    "d 1.0.0": {
      "myapp": "<1.0.0"
    }
  }, result: {
    'myapp from root': '1.0.0',
    'a': '1.0.0',
    'b': '1.0.0',
    'c': '1.0.0',
    'd': '2.0.0'
  }, maxTries: 3);
}
sdkConstraint() {
  var badVersion = '0.0.0-nope';
  var goodVersion = sdk.version.toString();
  testResolve('root matches SDK', {
    'myapp 0.0.0': {
      'sdk': goodVersion
    }
  }, result: {
    'myapp from root': '0.0.0'
  });
  testResolve('root does not match SDK', {
    'myapp 0.0.0': {
      'sdk': badVersion
    }
  }, error: couldNotSolve);
  testResolve('dependency does not match SDK', {
    'myapp 0.0.0': {
      'foo': 'any'
    },
    'foo 0.0.0': {
      'sdk': badVersion
    }
  }, error: couldNotSolve);
  testResolve('transitive dependency does not match SDK', {
    'myapp 0.0.0': {
      'foo': 'any'
    },
    'foo 0.0.0': {
      'bar': 'any'
    },
    'bar 0.0.0': {
      'sdk': badVersion
    }
  }, error: couldNotSolve);
  testResolve('selects a dependency version that allows the SDK', {
    'myapp 0.0.0': {
      'foo': 'any'
    },
    'foo 1.0.0': {
      'sdk': goodVersion
    },
    'foo 2.0.0': {
      'sdk': goodVersion
    },
    'foo 3.0.0': {
      'sdk': badVersion
    },
    'foo 4.0.0': {
      'sdk': badVersion
    }
  }, result: {
    'myapp from root': '0.0.0',
    'foo': '2.0.0'
  }, maxTries: 3);
  testResolve('selects a transitive dependency version that allows the SDK', {
    'myapp 0.0.0': {
      'foo': 'any'
    },
    'foo 1.0.0': {
      'bar': 'any'
    },
    'bar 1.0.0': {
      'sdk': goodVersion
    },
    'bar 2.0.0': {
      'sdk': goodVersion
    },
    'bar 3.0.0': {
      'sdk': badVersion
    },
    'bar 4.0.0': {
      'sdk': badVersion
    }
  }, result: {
    'myapp from root': '0.0.0',
    'foo': '1.0.0',
    'bar': '2.0.0'
  }, maxTries: 3);
  testResolve(
      'selects a dependency version that allows a transitive '
          'dependency that allows the SDK',
      {
    'myapp 0.0.0': {
      'foo': 'any'
    },
    'foo 1.0.0': {
      'bar': '1.0.0'
    },
    'foo 2.0.0': {
      'bar': '2.0.0'
    },
    'foo 3.0.0': {
      'bar': '3.0.0'
    },
    'foo 4.0.0': {
      'bar': '4.0.0'
    },
    'bar 1.0.0': {
      'sdk': goodVersion
    },
    'bar 2.0.0': {
      'sdk': goodVersion
    },
    'bar 3.0.0': {
      'sdk': badVersion
    },
    'bar 4.0.0': {
      'sdk': badVersion
    }
  }, result: {
    'myapp from root': '0.0.0',
    'foo': '2.0.0',
    'bar': '2.0.0'
  }, maxTries: 3);
}
void prerelease() {
  testResolve('prefer stable versions over unstable', {
    'myapp 0.0.0': {
      'a': 'any'
    },
    'a 1.0.0': {},
    'a 1.1.0-dev': {},
    'a 2.0.0-dev': {},
    'a 3.0.0-dev': {}
  }, result: {
    'myapp from root': '0.0.0',
    'a': '1.0.0'
  });
  testResolve('use latest allowed prerelease if no stable versions match', {
    'myapp 0.0.0': {
      'a': '<2.0.0'
    },
    'a 1.0.0-dev': {},
    'a 1.1.0-dev': {},
    'a 1.9.0-dev': {},
    'a 3.0.0': {}
  }, result: {
    'myapp from root': '0.0.0',
    'a': '1.9.0-dev'
  });
  testResolve('use an earlier stable version on a < constraint', {
    'myapp 0.0.0': {
      'a': '<2.0.0'
    },
    'a 1.0.0': {},
    'a 1.1.0': {},
    'a 2.0.0-dev': {},
    'a 2.0.0': {}
  }, result: {
    'myapp from root': '0.0.0',
    'a': '1.1.0'
  });
  testResolve('prefer a stable version even if constraint mentions unstable', {
    'myapp 0.0.0': {
      'a': '<=2.0.0-dev'
    },
    'a 1.0.0': {},
    'a 1.1.0': {},
    'a 2.0.0-dev': {},
    'a 2.0.0': {}
  }, result: {
    'myapp from root': '0.0.0',
    'a': '1.1.0'
  });
}
void override() {
  testResolve('chooses best version matching override constraint', {
    'myapp 0.0.0': {
      'a': 'any'
    },
    'a 1.0.0': {},
    'a 2.0.0': {},
    'a 3.0.0': {}
  }, overrides: {
    'a': '<3.0.0'
  }, result: {
    'myapp from root': '0.0.0',
    'a': '2.0.0'
  });
  testResolve('uses override as dependency', {
    'myapp 0.0.0': {},
    'a 1.0.0': {},
    'a 2.0.0': {},
    'a 3.0.0': {}
  }, overrides: {
    'a': '<3.0.0'
  }, result: {
    'myapp from root': '0.0.0',
    'a': '2.0.0'
  });
  testResolve('ignores other constraints on overridden package', {
    'myapp 0.0.0': {
      'b': 'any',
      'c': 'any'
    },
    'a 1.0.0': {},
    'a 2.0.0': {},
    'a 3.0.0': {},
    'b 1.0.0': {
      'a': '1.0.0'
    },
    'c 1.0.0': {
      'a': '3.0.0'
    }
  }, overrides: {
    'a': '2.0.0'
  }, result: {
    'myapp from root': '0.0.0',
    'a': '2.0.0',
    'b': '1.0.0',
    'c': '1.0.0'
  });
  testResolve('backtracks on overidden package for its constraints', {
    'myapp 0.0.0': {
      'shared': '2.0.0'
    },
    'a 1.0.0': {
      'shared': 'any'
    },
    'a 2.0.0': {
      'shared': '1.0.0'
    },
    'shared 1.0.0': {},
    'shared 2.0.0': {}
  }, overrides: {
    'a': '<3.0.0'
  }, result: {
    'myapp from root': '0.0.0',
    'a': '1.0.0',
    'shared': '2.0.0'
  }, maxTries: 2);
  testResolve('override compatible with locked dependency', {
    'myapp 0.0.0': {
      'foo': 'any'
    },
    'foo 1.0.0': {
      'bar': '1.0.0'
    },
    'foo 1.0.1': {
      'bar': '1.0.1'
    },
    'foo 1.0.2': {
      'bar': '1.0.2'
    },
    'bar 1.0.0': {},
    'bar 1.0.1': {},
    'bar 1.0.2': {}
  }, lockfile: {
    'foo': '1.0.1'
  }, overrides: {
    'foo': '<1.0.2'
  }, result: {
    'myapp from root': '0.0.0',
    'foo': '1.0.1',
    'bar': '1.0.1'
  });
  testResolve('override incompatible with locked dependency', {
    'myapp 0.0.0': {
      'foo': 'any'
    },
    'foo 1.0.0': {
      'bar': '1.0.0'
    },
    'foo 1.0.1': {
      'bar': '1.0.1'
    },
    'foo 1.0.2': {
      'bar': '1.0.2'
    },
    'bar 1.0.0': {},
    'bar 1.0.1': {},
    'bar 1.0.2': {}
  }, lockfile: {
    'foo': '1.0.1'
  }, overrides: {
    'foo': '>1.0.1'
  }, result: {
    'myapp from root': '0.0.0',
    'foo': '1.0.2',
    'bar': '1.0.2'
  });
  testResolve('no version that matches override', {
    'myapp 0.0.0': {},
    'foo 2.0.0': {},
    'foo 2.1.3': {}
  }, overrides: {
    'foo': '>=1.0.0 <2.0.0'
  }, error: noVersion(['myapp']));
  testResolve('override a bad source without error', {
    'myapp 0.0.0': {
      'foo from bad': 'any'
    },
    'foo 0.0.0': {}
  }, overrides: {
    'foo': 'any'
  }, result: {
    'myapp from root': '0.0.0',
    'foo': '0.0.0'
  });
}
void downgrade() {
  testResolve("downgrades a dependency to the lowest matching version", {
    'myapp 0.0.0': {
      'foo': '>=2.0.0 <3.0.0'
    },
    'foo 1.0.0': {},
    'foo 2.0.0-dev': {},
    'foo 2.0.0': {},
    'foo 2.1.0': {}
  }, lockfile: {
    'foo': '2.1.0'
  }, result: {
    'myapp from root': '0.0.0',
    'foo': '2.0.0'
  }, downgrade: true);
  testResolve(
      'use earliest allowed prerelease if no stable versions match '
          'while downgrading',
      {
    'myapp 0.0.0': {
      'a': '>=2.0.0-dev.1 <3.0.0'
    },
    'a 1.0.0': {},
    'a 2.0.0-dev.1': {},
    'a 2.0.0-dev.2': {},
    'a 2.0.0-dev.3': {}
  }, result: {
    'myapp from root': '0.0.0',
    'a': '2.0.0-dev.1'
  }, downgrade: true);
}
testResolve(String description, Map packages, {Map lockfile, Map overrides,
    Map result, FailMatcherBuilder error, int maxTries, bool downgrade: false}) {
  _testResolve(
      test,
      description,
      packages,
      lockfile: lockfile,
      overrides: overrides,
      result: result,
      error: error,
      maxTries: maxTries,
      downgrade: downgrade);
}
solo_testResolve(String description, Map packages, {Map lockfile, Map overrides,
    Map result, FailMatcherBuilder error, int maxTries, bool downgrade: false}) {
  log.verbosity = log.Verbosity.SOLVER;
  _testResolve(
      solo_test,
      description,
      packages,
      lockfile: lockfile,
      overrides: overrides,
      result: result,
      error: error,
      maxTries: maxTries,
      downgrade: downgrade);
}
_testResolve(void testFn(String description, Function body), String description,
    Map packages, {Map lockfile, Map overrides, Map result,
    FailMatcherBuilder error, int maxTries, bool downgrade: false}) {
  if (maxTries == null) maxTries = 1;
  testFn(description, () {
    var cache = new SystemCache('.');
    source1 = new MockSource('mock1');
    source2 = new MockSource('mock2');
    cache.register(source1);
    cache.register(source2);
    cache.sources.setDefault(source1.name);
    var root;
    packages.forEach((description, dependencies) {
      var id = parseSpec(description);
      var package =
          mockPackage(id, dependencies, id.name == 'myapp' ? overrides : null);
      if (id.name == 'myapp') {
        root = package;
      } else {
        (cache.sources[id.source] as MockSource).addPackage(
            id.description,
            package);
      }
    });
    if (result != null) {
      var newResult = {};
      result.forEach((description, version) {
        var id = parseSpec(description, version);
        newResult[id.name] = id;
      });
      result = newResult;
    }
    var realLockFile = new LockFile.empty();
    if (lockfile != null) {
      lockfile.forEach((name, version) {
        version = new Version.parse(version);
        realLockFile.packages[name] =
            new PackageId(name, source1.name, version, name);
      });
    }
    var future = resolveVersions(
        downgrade ? SolveType.DOWNGRADE : SolveType.GET,
        cache.sources,
        root,
        lockFile: realLockFile);
    var matcher;
    if (result != null) {
      matcher = new SolveSuccessMatcher(result, maxTries);
    } else if (error != null) {
      matcher = error(maxTries);
    }
    expect(future, completion(matcher));
  });
}
typedef SolveFailMatcher FailMatcherBuilder(int maxTries);
FailMatcherBuilder noVersion(List<String> packages) {
  return (maxTries) =>
      new SolveFailMatcher(packages, maxTries, NoVersionException);
}
FailMatcherBuilder disjointConstraint(List<String> packages) {
  return (maxTries) =>
      new SolveFailMatcher(packages, maxTries, DisjointConstraintException);
}
FailMatcherBuilder descriptionMismatch(String package, String depender1,
    String depender2) {
  return (maxTries) =>
      new SolveFailMatcher(
          [package, depender1, depender2],
          maxTries,
          DescriptionMismatchException);
}
SolveFailMatcher couldNotSolve(maxTries) =>
    new SolveFailMatcher([], maxTries, null);
FailMatcherBuilder sourceMismatch(String package, String depender1,
    String depender2) {
  return (maxTries) =>
      new SolveFailMatcher(
          [package, depender1, depender2],
          maxTries,
          SourceMismatchException);
}
unknownSource(String depender, String dependency, String source) {
  return (maxTries) =>
      new SolveFailMatcher(
          [depender, dependency, source],
          maxTries,
          UnknownSourceException);
}
class SolveSuccessMatcher implements Matcher {
  final Map<String, PackageId> _expected;
  final int _maxTries;
  SolveSuccessMatcher(this._expected, this._maxTries);
  Description describe(Description description) {
    return description.add(
        'Solver to use at most $_maxTries attempts to find:\n'
            '${_listPackages(_expected.values)}');
  }
  Description describeMismatch(SolveResult result, Description description,
      Map state, bool verbose) {
    if (!result.succeeded) {
      description.add('Solver failed with:\n${result.error}');
      return null;
    }
    description.add('Resolved:\n${_listPackages(result.packages)}\n');
    description.add(state['failures']);
    return description;
  }
  bool matches(SolveResult result, Map state) {
    if (!result.succeeded) return false;
    var expected = new Map.from(_expected);
    var failures = new StringBuffer();
    for (var id in result.packages) {
      if (!expected.containsKey(id.name)) {
        failures.writeln('Should not have selected $id');
      } else {
        var expectedId = expected.remove(id.name);
        if (id != expectedId) {
          failures.writeln('Expected $expectedId, not $id');
        }
      }
    }
    if (!expected.isEmpty) {
      failures.writeln('Missing:\n${_listPackages(expected.values)}');
    }
    if (result.attemptedSolutions != 1 &&
        result.attemptedSolutions != _maxTries) {
      failures.writeln('Took ${result.attemptedSolutions} attempts');
    }
    if (!failures.isEmpty) {
      state['failures'] = failures.toString();
      return false;
    }
    return true;
  }
  String _listPackages(Iterable<PackageId> packages) {
    return '- ${packages.join('\n- ')}';
  }
}
class SolveFailMatcher implements Matcher {
  final Iterable<String> _expected;
  final int _maxTries;
  final Type _expectedType;
  SolveFailMatcher(this._expected, this._maxTries, this._expectedType);
  Description describe(Description description) {
    description.add('Solver should fail after at most $_maxTries attempts.');
    if (!_expected.isEmpty) {
      var textList = _expected.map((s) => '"$s"').join(", ");
      description.add(' The error should contain $textList.');
    }
    return description;
  }
  Description describeMismatch(SolveResult result, Description description,
      Map state, bool verbose) {
    description.add(state['failures']);
    return description;
  }
  bool matches(SolveResult result, Map state) {
    var failures = new StringBuffer();
    if (result.succeeded) {
      failures.writeln('Solver succeeded');
    } else {
      if (_expectedType != null && result.error.runtimeType != _expectedType) {
        failures.writeln(
            'Should have error type $_expectedType, got ' '${result.error.runtimeType}');
      }
      var message = result.error.toString();
      for (var expected in _expected) {
        if (!message.contains(expected)) {
          failures.writeln(
              'Expected error to contain "$expected", got:\n$message');
        }
      }
      if (result.attemptedSolutions != 1 &&
          result.attemptedSolutions != _maxTries) {
        failures.writeln('Took ${result.attemptedSolutions} attempts');
      }
    }
    if (!failures.isEmpty) {
      state['failures'] = failures.toString();
      return false;
    }
    return true;
  }
}
class MockSource extends CachedSource {
  final _packages = <String, Map<Version, Package>>{};
  final _requestedVersions = new Set<String>();
  final _requestedPubspecs = new Map<String, Set<Version>>();
  final String name;
  final hasMultipleVersions = true;
  MockSource(this.name);
  dynamic parseDescription(String containingPath, description,
      {bool fromLockFile: false}) =>
      description;
  bool descriptionsEqual(description1, description2) =>
      description1 == description2;
  Future<String> getDirectory(PackageId id) {
    return new Future.value('${id.name}-${id.version}');
  }
  Future<List<Version>> getVersions(String name, String description) {
    return new Future.sync(() {
      if (_requestedVersions.contains(description)) {
        throw new Exception(
            'Version list for $description was already ' 'requested.');
      }
      _requestedVersions.add(description);
      if (!_packages.containsKey(description)) {
        throw new Exception(
            'MockSource does not have a package matching ' '"$description".');
      }
      return _packages[description].keys.toList();
    });
  }
  Future<Pubspec> describeUncached(PackageId id) {
    return new Future.sync(() {
      if (_requestedPubspecs.containsKey(id.description) &&
          _requestedPubspecs[id.description].contains(id.version)) {
        throw new Exception('Pubspec for $id was already requested.');
      }
      _requestedPubspecs.putIfAbsent(id.description, () => new Set<Version>());
      _requestedPubspecs[id.description].add(id.version);
      return _packages[id.description][id.version].pubspec;
    });
  }
  Future<Package> downloadToSystemCache(PackageId id) =>
      throw new UnsupportedError('Cannot download mock packages');
  List<Package> getCachedPackages() =>
      throw new UnsupportedError('Cannot get mock packages');
  Future<Pair<int, int>> repairCachedPackages() =>
      throw new UnsupportedError('Cannot repair mock packages');
  void addPackage(String description, Package package) {
    _packages.putIfAbsent(description, () => new Map<Version, Package>());
    _packages[description][package.version] = package;
  }
}
Package mockPackage(PackageId id, Map dependencyStrings, Map overrides) {
  var sdkConstraint = null;
  var dependencies = <PackageDep>[];
  var devDependencies = <PackageDep>[];
  dependencyStrings.forEach((spec, constraint) {
    var isDev = spec.startsWith("(dev) ");
    if (isDev) {
      spec = spec.substring("(dev) ".length);
    }
    var dep =
        parseSpec(spec).withConstraint(new VersionConstraint.parse(constraint));
    if (dep.name == 'sdk') {
      sdkConstraint = dep.constraint;
      return;
    }
    if (isDev) {
      devDependencies.add(dep);
    } else {
      dependencies.add(dep);
    }
  });
  var dependencyOverrides = <PackageDep>[];
  if (overrides != null) {
    overrides.forEach((spec, constraint) {
      dependencyOverrides.add(
          parseSpec(spec).withConstraint(new VersionConstraint.parse(constraint)));
    });
  }
  return new Package.inMemory(
      new Pubspec(
          id.name,
          version: id.version,
          dependencies: dependencies,
          devDependencies: devDependencies,
          dependencyOverrides: dependencyOverrides,
          sdkConstraint: sdkConstraint));
}
PackageId parseSpec(String text, [String version]) {
  var pattern = new RegExp(r"(([a-z_]*)(-[a-z_]+)?)( ([^ ]+))?( from (.*))?$");
  var match = pattern.firstMatch(text);
  if (match == null) {
    throw new FormatException("Could not parse spec '$text'.");
  }
  var description = match[1];
  var name = match[2];
  var parsedVersion;
  if (version != null) {
    if (match[5] != null) {
      throw new ArgumentError(
          "Spec '$text' should not contain a version "
              "since '$version' was passed in explicitly.");
    }
    parsedVersion = new Version.parse(version);
  } else {
    if (match[5] != null) {
      parsedVersion = new Version.parse(match[5]);
    } else {
      parsedVersion = Version.none;
    }
  }
  var source = "mock1";
  if (match[7] != null) {
    source = match[7];
    if (source == "root") source = null;
  }
  return new PackageId(name, source, parsedVersion, description);
}