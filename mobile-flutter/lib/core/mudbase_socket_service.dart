import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import '../config/env_config.dart';

enum SocketConnectionStatus { disconnected, connecting, connected, error }

typedef SocketStatusListener = void Function(SocketConnectionStatus status);
typedef SocketEventHandler = void Function(Map<String, dynamic> payload);

/// Ports the web app's `MudbaseSocket` (`web/src/lib/mudbase-socket.ts`) to
/// Dart: one shared Socket.IO connection, authenticated with the current
/// session's access token, used to subscribe to a collection's realtime
/// room (`subscribe:collection` -> `db:create`/`db:update`).
///
/// Unlike the sibling ecommerce Flutter app (which explicitly opted out of
/// realtime), this app's feed requires it, so this service is new relative
/// to that port - confirmed live in this build's own smoke test (see
/// `plan/build-plan.md` finding #6: a `db:create` event was received within
/// under a second of a second account's plain REST post-create call).
class MudbaseSocketService {
  socket_io.Socket? _socket;
  String? _connectedToken;
  final Set<SocketStatusListener> _statusListeners = <SocketStatusListener>{};

  /// Connects (or reconnects, if the token changed since the last
  /// connection) authenticated as [token]. Guest browsing followed by a
  /// same-session login would otherwise leave the socket authenticated as a
  /// stale identity if this only checked "already connected" - same
  /// rationale as the web app's `connect()`.
  void connect(String token) {
    if (_socket?.connected == true && _connectedToken == token) return;
    _socket?.dispose();

    _connectedToken = token;
    _emitStatus(SocketConnectionStatus.connecting);
    final socket = socket_io.io(
      EnvConfig.mudbaseBaseUrl,
      socket_io.OptionBuilder()
          .setPath('/socket.io/')
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': token})
          .setReconnectionAttempts(10)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(30000)
          .enableReconnection()
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) => _emitStatus(SocketConnectionStatus.connected));
    socket.onDisconnect(
      (_) => _emitStatus(SocketConnectionStatus.disconnected),
    );
    socket.onConnectError((_) => _emitStatus(SocketConnectionStatus.error));
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _connectedToken = null;
    _emitStatus(SocketConnectionStatus.disconnected);
  }

  bool get connected => _socket?.connected ?? false;

  /// Returns an unsubscribe function, same ergonomics as the web app's
  /// `onStatus`.
  void Function() onStatus(SocketStatusListener listener) {
    _statusListeners.add(listener);
    return () => _statusListeners.remove(listener);
  }

  void _emitStatus(SocketConnectionStatus status) {
    for (final listener in _statusListeners) {
      listener(status);
    }
  }

  void emit(String event, Map<String, dynamic> data) {
    final socket = _socket;
    if (socket == null || !socket.connected) return;
    socket.emit(event, data);
  }

  /// Returns an unsubscribe function. [handler] receives the raw event
  /// payload as a `Map<String, dynamic>` - every Mudbase realtime event this
  /// app listens to (`db:create`/`db:update`) sends a JSON object shaped
  /// `{ projectId, collectionId, action, data, timestamp }`.
  void Function() on(String event, SocketEventHandler handler) {
    void wrapped(dynamic payload) {
      if (payload is Map) {
        handler(Map<String, dynamic>.from(payload));
      }
    }

    _socket?.on(event, wrapped);
    final socket = _socket;
    return () => socket?.off(event, wrapped);
  }
}
