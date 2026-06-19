import 'merchant_session_store_stub.dart'
    if (dart.library.html) 'merchant_session_store_web.dart';

class MerchantSession {
  const MerchantSession({required this.token, required this.user});

  final String token;
  final Map<String, dynamic> user;
}

abstract class MerchantSessionStore {
  Future<MerchantSession?> read();

  Future<void> save(MerchantSession session);

  Future<void> clear();

  factory MerchantSessionStore() = MerchantSessionStoreImpl;
}
