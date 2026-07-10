class AppAssets {
  AppAssets._();

  static const String _imagesPath = 'assets/images';
  static const String _logosPath = 'assets/logos';
  static const String _placeholdersPath = '$_imagesPath/placeholders';

  // Frontend-only fallbacks for images returned by the API.
  static const String defaultUserAvatar =
      '$_placeholdersPath/default_user_avatar.png';
  static const String defaultStore = '$_placeholdersPath/default_store.png';
  static const String defaultProduct = '$_placeholdersPath/default_product.png';
  static const String defaultCourier = '$_placeholdersPath/default_courier.png';

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
