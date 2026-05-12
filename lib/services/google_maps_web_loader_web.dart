import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

Completer<void>? _loaderCompleter;

Future<void> ensureGoogleMapsWebSdkLoaded(String apiKey) {
  if (_hasGoogleMapsSdk) {
    return Future<void>.value();
  }

  final trimmedKey = apiKey.trim();
  if (trimmedKey.isEmpty) {
    return Future<void>.error(
      StateError('Missing Google Maps JavaScript API key.'),
    );
  }

  final existingScript = web.document.getElementById(_scriptId);
  if (existingScript != null && _loaderCompleter != null) {
    return _loaderCompleter!.future;
  }

  _loaderCompleter = Completer<void>();

  final script = web.document.createElement('script') as web.HTMLScriptElement
    ..id = _scriptId
    ..async = true
    ..defer = true
    ..src =
        'https://maps.googleapis.com/maps/api/js?key=${Uri.encodeQueryComponent(trimmedKey)}';

  script.addEventListener(
    'load',
    ((web.Event _) {
      if (!(_loaderCompleter?.isCompleted ?? true)) {
        _loaderCompleter!.complete();
      }
    }).toJS,
  );

  script.addEventListener(
    'error',
    ((web.Event _) {
      if (!(_loaderCompleter?.isCompleted ?? true)) {
        _loaderCompleter!.completeError(
          StateError('Unable to load the Google Maps JavaScript SDK.'),
        );
      }
    }).toJS,
  );

  web.document.head?.appendChild(script);
  return _loaderCompleter!.future;
}

const _scriptId = 'google-maps-js-sdk';

bool get _hasGoogleMapsSdk {
  if (web.window.hasProperty('google'.toJS) != true.toJS) {
    return false;
  }

  final google = web.window.getProperty<JSObject?>('google'.toJS);
  return google != null && google.hasProperty('maps'.toJS) == true.toJS;
}
