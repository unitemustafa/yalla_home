enum AuthSessionMode {
  temporary('temporary'),
  persistent('persistent');

  const AuthSessionMode(this.wireName);

  final String wireName;

  bool get isRemembered => this == AuthSessionMode.persistent;

  static AuthSessionMode parse(Object? value) {
    return switch (value?.toString()) {
      'temporary' => AuthSessionMode.temporary,
      'persistent' => AuthSessionMode.persistent,
      _ => throw const FormatException('Invalid authentication session mode.'),
    };
  }
}
