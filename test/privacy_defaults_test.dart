import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native reporting is off before Dart starts', () {
    final ios = File('ios/Runner/Info.plist').readAsStringSync();
    final android = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    for (final permission in [
      'com.google.android.gms.permission.AD_ID',
      'android.permission.ACCESS_ADSERVICES_AD_ID',
      'android.permission.ACCESS_ADSERVICES_ATTRIBUTION',
    ]) {
      expect(
        android,
        contains('android:name="$permission" tools:node="remove"'),
      );
    }
    for (final key in [
      'FIREBASE_ANALYTICS_COLLECTION_ENABLED',
      'FirebaseCrashlyticsCollectionEnabled',
      'GOOGLE_ANALYTICS_IDFA_COLLECTION_ENABLED',
      'GOOGLE_ANALYTICS_DEFAULT_ALLOW_ANALYTICS_STORAGE',
      'GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_STORAGE',
      'GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_USER_DATA',
      'GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_PERSONALIZATION_SIGNALS',
    ]) {
      expect(ios, matches('<key>$key</key>\\s*<false/>'), reason: key);
    }
    for (final key in [
      'firebase_analytics_collection_enabled',
      'firebase_crashlytics_collection_enabled',
      'google_analytics_adid_collection_enabled',
      'google_analytics_default_allow_analytics_storage',
      'google_analytics_default_allow_ad_storage',
      'google_analytics_default_allow_ad_user_data',
      'google_analytics_default_allow_ad_personalization_signals',
    ]) {
      expect(
        android,
        matches('android:name="$key"\\s+android:value="false"'),
        reason: key,
      );
    }
  });
}
