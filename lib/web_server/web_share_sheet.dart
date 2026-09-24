import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'local_web_server.dart';

/// BottomSheet hướng dẫn và cung cấp mã QR/URL để mở Web Dashboard trên máy tính
class WebShareSheet extends StatefulWidget {
  const WebShareSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const WebShareSheet(),
    );
  }

  @override
  State<WebShareSheet> createState() => _WebShareSheetState();
}

class _WebShareSheetState extends State<WebShareSheet> {
  final _server = LocalWebServer.instance;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Tự động khởi động nếu chưa chạy
    if (!_server.isRunning) {
      _startServer();
    }
  }

  Future<void> _startServer() async {
    setState(() => _isLoading = true);
    await _server.startServer();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _stopServer() async {
    setState(() => _isLoading = true);
    await _server.stopServer();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _copyUrl(String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép địa chỉ Web vào clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = _server.serverUrl;
    final isRunning = _server.isRunning && url != null;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161A29),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      padding: EdgeInsets.fromLTRB(
        24.0,
        16.0,
        24.0,
        MediaQuery.of(context).padding.bottom + 24.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18.0),

          // Tiêu đề
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.laptop_chromebook,
                  color: Color(0xFF00E5FF),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Xem trên máy tính (Wi-Fi)',
                      style: TextStyle(
                        fontSize: 17.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      isRunning
                          ? 'Máy chủ cục bộ đang phát sóng'
                          : 'Máy chủ đang tắt',
                      style: TextStyle(
                        fontSize: 12.0,
                        color: isRunning
                            ? const Color(0xFF00E676)
                            : Colors.white54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Nút bật / tắt
              if (_isLoading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Switch(
                  value: _server.isRunning,
                  activeTrackColor: const Color(0xFF00E5FF),
                  onChanged: (val) {
                    if (val) {
                      _startServer();
                    } else {
                      _stopServer();
                    }
                  },
                ),
            ],
          ),

          const SizedBox(height: 20.0),

          if (isRunning) ...[
            // Khung mã QR
            Container(
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18.0),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
                    blurRadius: 20.0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: url,
                version: QrVersions.auto,
                size: 170.0,
                backgroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 18.0),

            // Banner hiển thị URL
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14.0,
                vertical: 10.0,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF0F121D),
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.link,
                    color: Color(0xFF00E5FF),
                    size: 20,
                  ),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: Text(
                      url,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00E5FF),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18, color: Colors.white70),
                    tooltip: 'Sao chép',
                    onPressed: () => _copyUrl(url),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16.0),

            // Hướng dẫn
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(color: Colors.white10),
              ),
              child: const Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('1. ', style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(
                          'Đảm bảo máy tính và điện thoại kết nối cùng mạng Wi-Fi.',
                          style: TextStyle(fontSize: 12.0, color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.0),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('2. ', style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(
                          'Mở trình duyệt (Chrome, Safari, Edge) và nhập địa chỉ URL ở trên.',
                          style: TextStyle(fontSize: 12.0, color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else if (_server.isRunning && _server.localIp == null) ...[
            // Đã chạy nhưng chưa tìm thấy IP Wi-Fi
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.wifi_off_outlined,
                    size: 48,
                    color: Colors.amber,
                  ),
                  const SizedBox(height: 12.0),
                  const Text(
                    'Chưa kết nối mạng Wi-Fi',
                    style: TextStyle(
                      fontSize: 15.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6.0),
                  const Text(
                    'Máy chủ đã sẵn sàng nhưng chưa nhận diện được địa chỉ IP Wi-Fi. Hãy kết nối điện thoại vào một mạng Wi-Fi rồi thử lại.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: Colors.white60),
                  ),
                  const SizedBox(height: 16.0),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 10.0,
                      ),
                    ),
                    onPressed: _startServer,
                    icon: const Icon(Icons.refresh),
                    label: const Text(
                      'Thử tìm lại IP',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Khi máy chủ tắt hoặc lỗi
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Column(
                children: [
                  Icon(
                    _server.lastError != null
                        ? Icons.error_outline
                        : Icons.wifi_off_outlined,
                    size: 48,
                    color: _server.lastError != null
                        ? Colors.redAccent
                        : Colors.white38,
                  ),
                  const SizedBox(height: 12.0),
                  Text(
                    _server.lastError != null
                        ? 'Không thể khởi động máy chủ'
                        : 'Máy chủ web nội bộ đang tắt',
                    style: const TextStyle(
                      fontSize: 15.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6.0),
                  Text(
                    _server.lastError ??
                        'Bật máy chủ để truyền phát dữ liệu đo trực tiếp sang trình duyệt máy tính mà không cần internet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: _server.lastError != null
                          ? Colors.red.shade200
                          : Colors.white60,
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 10.0,
                      ),
                    ),
                    onPressed: _startServer,
                    icon: const Icon(Icons.power_settings_new),
                    label: const Text(
                      'Khởi động máy chủ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
