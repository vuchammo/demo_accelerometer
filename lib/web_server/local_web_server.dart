import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../database/recording_database.dart';
import 'web_dashboard_html.dart';

/// Dịch vụ máy chủ HTTP cục bộ chạy trực tiếp trên điện thoại
/// Cho phép máy tính / laptop trong cùng mạng Wi-Fi truy cập Web Dashboard
class LocalWebServer {
  LocalWebServer._();
  static final LocalWebServer instance = LocalWebServer._();

  HttpServer? _server;
  int _port = 8080;
  String? _localIp;

  bool get isRunning => _server != null;
  int get port => _port;
  String? get localIp => _localIp;
  String? get serverUrl =>
      isRunning && _localIp != null ? 'http://$_localIp:$_port' : null;

  /// Lấy địa chỉ IP mạng nội bộ (Wi-Fi) của thiết bị
  Future<String?> getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      // Ưu tiên wlan, en, eth...
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && !addr.address.startsWith('127.')) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      debugPrint('Error finding local IP: $e');
    }
    return null;
  }

  /// Khởi động máy chủ web cục bộ
  Future<bool> startServer({int port = 8080}) async {
    if (isRunning) return true;

    try {
      _port = port;
      _localIp = await getLocalIpAddress();

      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      debugPrint('LocalWebServer running on port $_port, IP: $_localIp');

      _server!.listen(
        _handleRequest,
        onError: (e) {
          debugPrint('LocalWebServer request error: $e');
        },
      );

      return true;
    } catch (e) {
      debugPrint('Error starting LocalWebServer: $e');
      _server = null;
      return false;
    }
  }

  /// Dừng máy chủ web
  Future<void> stopServer() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      debugPrint('LocalWebServer stopped.');
    }
  }

  void _handleRequest(HttpRequest request) async {
    // Thêm CORS headers để web có thể gọi API mà không bị chặn
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add(
      'Access-Control-Allow-Methods',
      'GET, POST, OPTIONS, DELETE',
    );
    request.response.headers.add(
      'Access-Control-Allow-Headers',
      'Content-Type, Origin, Accept',
    );

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    final path = request.uri.path;

    try {
      // 1. Phục vụ Web Dashboard HTML
      if (path == '/' || path == '/index.html') {
        request.response.headers.contentType = ContentType.html;
        request.response.write(webDashboardHtml);
        await request.response.close();
        return;
      }

      // 2. API: Lấy danh sách tất cả các sessions
      if (path == '/api/sessions') {
        final sessions = await RecordingDatabase.instance.getAllSessions();
        final jsonList = sessions.map((s) => s.toMap()).toList();
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(jsonList));
        await request.response.close();
        return;
      }

      // 3. API: Cập nhật nhãn / tag cho session (/api/sessions/<id>/label)
      final sessionLabelRegex = RegExp(r'^/api/sessions/(\d+)/label$');
      final labelMatch = sessionLabelRegex.firstMatch(path);
      if (labelMatch != null && (request.method == 'POST' || request.method == 'PUT')) {
        final sessionId = int.parse(labelMatch.group(1)!);
        final content = await utf8.decoder.bind(request).join();
        String? newLabel;
        if (content.isNotEmpty) {
          try {
            final jsonBody = jsonDecode(content);
            if (jsonBody is Map && jsonBody.containsKey('label')) {
              newLabel = jsonBody['label'] as String?;
            }
          } catch (_) {}
        }
        await RecordingDatabase.instance.updateSessionLabel(sessionId, newLabel);
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'success': true, 'label': newLabel}));
        await request.response.close();
        return;
      }

      // 4. API: Lấy chi tiết session + data points (/api/sessions/<id>)
      final sessionDetailRegex = RegExp(r'^/api/sessions/(\d+)$');
      final match = sessionDetailRegex.firstMatch(path);
      if (match != null) {
        final sessionId = int.parse(match.group(1)!);
        final session = await RecordingDatabase.instance.getSessionById(
          sessionId,
        );
        if (session == null) {
          request.response.statusCode = HttpStatus.notFound;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'error': 'Session not found'}));
          await request.response.close();
          return;
        }

        final dataPoints = await RecordingDatabase.instance
            .getSessionDataPoints(sessionId);
        final jsonResult = {
          'session': session.toMap(),
          'dataPoints': dataPoints.map((p) => p.toJson()).toList(),
        };

        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(jsonResult));
        await request.response.close();
        return;
      }

      // 4. API: Trạng thái máy chủ
      if (path == '/api/status') {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'status': 'online',
            'ip': _localIp,
            'port': _port,
            'timestamp': DateTime.now().toIso8601String(),
          }),
        );
        await request.response.close();
        return;
      }

      // 5. Không tìm thấy trang
      request.response.statusCode = HttpStatus.notFound;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'error': 'Not Found'}));
      await request.response.close();
    } catch (e, stack) {
      debugPrint('Error handling request: $e\n$stack');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'error': e.toString()}));
        await request.response.close();
      } catch (_) {}
    }
  }
}
