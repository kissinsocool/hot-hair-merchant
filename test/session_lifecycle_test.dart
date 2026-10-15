import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:hot_pepper_merchant/core/network/api_client.dart';
import 'package:hot_pepper_merchant/features/auth/data/merchant_auth_repository.dart';
import 'package:hot_pepper_merchant/features/account/data/merchant_account_repository.dart';
import 'package:hot_pepper_merchant/features/auth/data/merchant_session_store.dart';
import 'package:hot_pepper_merchant/features/booking/data/booking_update_stream.dart';

class _Sink implements WebSocketSink {
  final sent = <dynamic>[];
  bool closed = false;
  @override
  void add(dynamic data) => sent.add(data);
  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    closed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Channel implements WebSocketChannel {
  final input = StreamController<dynamic>();
  @override
  final _Sink sink = _Sink();
  @override
  Stream<dynamic> get stream => input.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  tearDown(() {
    ApiClient.authToken = null;
    BookingUpdateStream.instance.stop();
  });

  test(
    'account switch closes A and authenticates B; stopped sockets cannot deliver stale events',
    () async {
      final channels = <_Channel>[];
      final updates = BookingUpdateStream(
        connect: (_) {
          final channel = _Channel();
          channels.add(channel);
          return channel;
        },
      );
      final events = <Map<String, dynamic>>[];
      final listener = updates.stream.listen(events.add);
      ApiClient.authToken = 'account-A';
      updates.start();
      updates.start();
      expect(channels.length, 1);
      channels.first.input.add(jsonEncode({'event': 'auth.required'}));
      await Future<void>.delayed(Duration.zero);
      expect(jsonDecode(channels.first.sink.sent.single)['token'], 'account-A');
      channels.first.input.add(
        jsonEncode({
          'event': 'booking.created',
          'booking': {'salonId': 'A'},
        }),
      );
      ApiClient.authToken = 'account-B';
      updates.start();
      expect(channels.first.sink.closed, isTrue);
      expect(channels.length, 2);
      channels.last.input.add(jsonEncode({'event': 'auth.required'}));
      channels.last.input.add(jsonEncode({'event': 'authenticated'}));
      await Future<void>.delayed(Duration.zero);
      expect(jsonDecode(channels.last.sink.sent.single)['token'], 'account-B');
      expect(events.map((event) => event['event']), ['authenticated']);
      updates.stop();
      updates.stop();
      expect(channels.last.sink.closed, isTrue);
      await listener.cancel();
      for (final channel in channels) {
        await channel.input.close();
      }
    },
  );

  test(
    'password rotation rebinds the active socket without remounting the home',
    () async {
      final channels = <_Channel>[];
      final updates = BookingUpdateStream(
        connect: (_) {
          final channel = _Channel();
          channels.add(channel);
          return channel;
        },
      );
      ApiClient.authToken = 'before-password-change';
      updates.start();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com/api'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(
              options.headers['Authorization'],
              'Bearer before-password-change',
            );
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'token': 'after-password-change',
                  'user': {'displayName': 'Merchant'},
                },
              ),
            );
          },
        ),
      );
      final repository = MerchantAccountRepository(
        apiClient: ApiClient(dio: dio),
        bookingUpdates: updates,
      );
      await repository.updateAccount(
        displayName: 'Merchant',
        currentPassword: 'old-password',
        newPassword: 'new-password',
      );
      expect(channels.length, 2);
      expect(channels.first.sink.closed, isTrue);
      channels.last.input.add(jsonEncode({'event': 'auth.required'}));
      await Future<void>.delayed(Duration.zero);
      expect(
        jsonDecode(channels.last.sink.sent.single)['token'],
        'after-password-change',
      );
      updates.stop();
      for (final channel in channels) {
        await channel.input.close();
      }
      dio.close(force: true);
    },
  );

  for (final role in PortalRole.values) {
    test(
      '$role logout revokes the old token and delayed failures preserve a new login',
      () async {
        final dio = Dio(BaseOptions(baseUrl: 'https://example.com/api'));
        final started = Completer<RequestOptions>();
        late RequestInterceptorHandler pending;
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              pending = handler;
              started.complete(options);
            },
          ),
        );
        final store = MerchantSessionStore(role: role);
        await store.save(const MerchantSession(token: 'A', user: {}));
        ApiClient.authToken = 'A';
        final repository = MerchantAuthRepository(
          role: role,
          sessionStore: store,
          apiClient: ApiClient(dio: dio),
        );
        final logout = repository.logout();
        final request = await started.future;
        expect(request.path, '/${role.name}/auth/logout');
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], 'Bearer A');
        expect(await store.read(), isNull);
        ApiClient.authToken = 'B';
        await store.save(const MerchantSession(token: 'B', user: {}));
        pending.reject(
          DioException(
            requestOptions: request,
            type: DioExceptionType.connectionTimeout,
          ),
        );
        await logout;
        expect(ApiClient.authToken, 'B');
        expect((await store.read())?.token, 'B');
        dio.close(force: true);
      },
    );
  }
}
