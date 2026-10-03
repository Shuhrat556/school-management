import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// flutter_secure_storage encrypts with Web Crypto (crypto.subtle), which browsers
// only expose in a secure context (HTTPS or localhost). Served over plain HTTP
// every write threw "Null check operator used on a null value", so no sign-in
// could finish. The plugin keeps its key in localStorage next to the data anyway,
// so storing the values in localStorage directly gives up no real protection.
FlutterSecureStorage createAppStorage() =>
    globalContext['isSecureContext'].dartify() == true
        ? const FlutterSecureStorage()
        : const LocalStorageFallback();

@visibleForTesting
class LocalStorageFallback extends FlutterSecureStorage {
  const LocalStorageFallback();

  static const _prefix = 'tamdansers.';

  JSObject get _store => globalContext.getProperty<JSObject>('localStorage'.toJS);

  // localStorage keys of this app, without the prefix
  List<String> get _keys {
    final length = _store.getProperty<JSNumber>('length'.toJS).toDartInt;
    return [
      for (var i = 0; i < length; i++)
        _store.callMethod<JSString>('key'.toJS, i.toJS).toDart,
    ].where((key) => key.startsWith(_prefix)).map((key) => key.substring(_prefix.length)).toList();
  }

  String? _get(String key) =>
      _store.callMethod<JSString?>('getItem'.toJS, '$_prefix$key'.toJS)?.toDart;

  void _remove(String key) => _store.callMethod<JSAny?>('removeItem'.toJS, '$_prefix$key'.toJS);

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _get(key);

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) return _remove(key);
    _store.callMethod<JSAny?>('setItem'.toJS, '$_prefix$key'.toJS, value.toJS);
  }

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _get(key) != null;

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _remove(key);

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => {for (final key in _keys) key: _get(key)!};

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _keys.forEach(_remove);
}
