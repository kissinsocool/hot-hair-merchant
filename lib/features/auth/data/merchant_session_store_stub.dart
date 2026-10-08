import 'merchant_session_store.dart';

class MerchantSessionStoreImpl implements MerchantSessionStore {
  MerchantSessionStoreImpl({this.role = PortalRole.merchant});

  final PortalRole role;
  MerchantSession? _session;

  @override
  Future<MerchantSession?> read() async => _session;

  @override
  Future<void> save(MerchantSession session) async {
    _session = session;
  }

  @override
  Future<void> clear() async {
    _session = null;
  }
}
