@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:tamdansers/services/app_storage_web.dart';

// Runs in Chrome: flutter test --platform chrome test/app_storage_web_test.dart
void main() {
  const storage = LocalStorageFallback();

  setUp(() => storage.deleteAll());

  test('keeps values in localStorage without Web Crypto', () async {
    await storage.write(key: 'access_token', value: 'token-1');
    await storage.write(key: 'user_role', value: 'teacher');

    expect(await storage.read(key: 'access_token'), 'token-1');
    expect(await storage.containsKey(key: 'user_role'), isTrue);
    expect(await storage.readAll(), {'access_token': 'token-1', 'user_role': 'teacher'});
  });

  test('null write and delete remove a value', () async {
    await storage.write(key: 'entity_id', value: '42');
    await storage.write(key: 'entity_id', value: null);
    expect(await storage.read(key: 'entity_id'), isNull);

    await storage.write(key: 'user_name', value: 'Ann');
    await storage.delete(key: 'user_name');
    expect(await storage.containsKey(key: 'user_name'), isFalse);
  });

  test('deleteAll leaves other localStorage keys alone', () async {
    final localStorage = globalContext.getProperty<JSObject>('localStorage'.toJS);
    localStorage.callMethod<JSAny?>('setItem'.toJS, 'other-app'.toJS, 'keep'.toJS);
    await storage.write(key: 'refresh_token', value: 'r');

    await storage.deleteAll();

    expect(await storage.readAll(), isEmpty);
    expect(localStorage.callMethod<JSString?>('getItem'.toJS, 'other-app'.toJS)?.toDart, 'keep');
    localStorage.callMethod<JSAny?>('removeItem'.toJS, 'other-app'.toJS);
  });
}
