import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class ForegroundServiceManager {
  ForegroundServiceManager._();
  static final ForegroundServiceManager instance =
      ForegroundServiceManager._();

  bool _isInitialized = false;

  /// Cấu hình Foreground Service và WakeLock
  void init() {
    if (_isInitialized) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'foreground_service_motion',
        channelName: 'Theo dõi chuyển động nền',
        channelDescription:
            'Dịch vụ duy trì tốc độ đọc cảm biến ổn định khi tắt màn hình',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );

    _isInitialized = true;
  }

  /// Khởi động Foreground Service để giữ CPU thức nhẹ khi tắt màn hình
  Future<bool> startService() async {
    if (!Platform.isAndroid) return false;

    init();

    if (await FlutterForegroundTask.isRunningService) {
      return true;
    }

    final NotificationPermission status =
        await FlutterForegroundTask.checkNotificationPermission();
    if (status != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    final ServiceRequestResult result =
        await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'Giám sát chuyển động',
      notificationText: 'Duy trì cảm biến gia tốc ổn định 500ms',
    );

    return result is ServiceRequestSuccess;
  }

  /// Dừng Foreground Service
  Future<bool> stopService() async {
    if (!Platform.isAndroid) return false;

    if (await FlutterForegroundTask.isRunningService) {
      final ServiceRequestResult result =
          await FlutterForegroundTask.stopService();
      return result is ServiceRequestSuccess;
    }
    return true;
  }
}
