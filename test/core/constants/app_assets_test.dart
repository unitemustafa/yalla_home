import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_home/core/constants/app_assets.dart';

void main() {
  test('bundled branding and placeholders stay optimized', () {
    const optimizedAssets = <String>[
      AppAssets.logo,
      AppAssets.defaultCourier,
      AppAssets.defaultProduct,
      AppAssets.defaultUserAvatar,
    ];

    var totalBytes = 0;
    for (final assetPath in optimizedAssets) {
      expect(assetPath, endsWith('.webp'));

      final asset = File(assetPath);
      expect(asset.existsSync(), isTrue, reason: '$assetPath is missing');
      totalBytes += asset.lengthSync();
    }

    expect(
      totalBytes,
      lessThan(256 * 1024),
      reason: 'Bundled local artwork should stay below 256 KiB',
    );
  });
}
