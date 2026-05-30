class AppAssets {
  AppAssets._();

  static const String _logosPath = 'assets/logos';

  static const String appIconLogo = '$_logosPath/yallahome_blacklogo.png';
  static const String lightThemeLogo = '$_logosPath/yallahome_whitelogo.png';
  static const String darkThemeLogo = '$_logosPath/yallahome_blacklogo.png';
  static const String logo = lightThemeLogo;
  static const String defaultAvatar = appIconLogo;

  static const String blackLogo = darkThemeLogo;
  static const String whiteLogo = lightThemeLogo;

  static String themedLogo({required bool isDarkMode}) {
    return isDarkMode ? darkThemeLogo : lightThemeLogo;
  }
}
