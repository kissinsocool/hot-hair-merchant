@TestOn('browser')
library;

// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter_test/flutter_test.dart';
import 'package:hot_pepper_merchant/features/auth/data/merchant_session_store.dart';

void main() {
  final storage = html.window.localStorage;
  const keys = [
    'merchant_auth_token',
    'merchant_auth_user',
    'merchant_auth_token_v2',
    'merchant_auth_user_v2',
    'admin_auth_token_v2',
    'admin_auth_user_v2',
  ];

  setUp(() {
    for (final key in keys) {
      storage.remove(key);
    }
  });
  tearDown(() {
    for (final key in keys) {
      storage.remove(key);
    }
  });

  test(
    'migrates the matching legacy session and keeps portal sessions separate',
    () async {
      storage['merchant_auth_token'] = 'old-admin-token';
      storage['merchant_auth_user'] = jsonEncode({'role': 'admin'});

      final merchantStore = MerchantSessionStore(role: PortalRole.merchant);
      final adminStore = MerchantSessionStore(role: PortalRole.admin);
      expect(await merchantStore.read(), isNull);
      expect(storage['merchant_auth_token'], 'old-admin-token');

      expect((await adminStore.read())?.token, 'old-admin-token');
      expect(storage['admin_auth_token_v2'], 'old-admin-token');
      expect(storage['merchant_auth_token'], isNull);

      await merchantStore.save(
        const MerchantSession(
          token: 'merchant-token',
          user: {'role': 'merchant'},
        ),
      );
      await merchantStore.clear();
      expect((await adminStore.read())?.token, 'old-admin-token');

      await merchantStore.save(
        const MerchantSession(
          token: 'new-merchant-token',
          user: {'role': 'merchant'},
        ),
      );
      await adminStore.clear();
      expect((await merchantStore.read())?.token, 'new-merchant-token');
    },
  );

  test(
    'migrates a legacy merchant session without exposing it to admin',
    () async {
      storage['merchant_auth_token'] = 'old-merchant-token';
      storage['merchant_auth_user'] = jsonEncode({'role': 'merchant'});

      final adminStore = MerchantSessionStore(role: PortalRole.admin);
      final merchantStore = MerchantSessionStore(role: PortalRole.merchant);
      expect(await adminStore.read(), isNull);
      expect((await merchantStore.read())?.token, 'old-merchant-token');
      expect(storage['merchant_auth_token_v2'], 'old-merchant-token');
    },
  );
}
