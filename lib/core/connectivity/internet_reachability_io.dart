import 'dart:io';

Future<bool?> hasInternetAccess({
  Duration timeout = const Duration(seconds: 2),
}) async {
  try {
    final result = await InternetAddress.lookup('example.com').timeout(timeout);
    return result.any((address) => address.rawAddress.isNotEmpty);
  } catch (_) {
    return false;
  }
}
