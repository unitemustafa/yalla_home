import 'browser_session_storage_base.dart';
import 'browser_session_storage_stub.dart'
    if (dart.library.js_interop) 'browser_session_storage_web.dart'
    as implementation;

export 'browser_session_storage_base.dart';

BrowserSessionStorage createBrowserSessionStorage() {
  return implementation.createBrowserSessionStorage();
}
