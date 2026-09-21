import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Khởi tạo plugin thông báo và cấu hình các kênh âm thanh
  Future<void> init() async {
    if (_isInitialized) return;

    // Cấu hình icon thông báo mặc định cho Android
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Cấu hình xin quyền cho iOS
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings: settings);

    // Xin quyền trên Android 13+
    await requestPermissions();

    // Tạo Notification Channel riêng kèm custom sound trên Android
    await _createNotificationChannels();

    _isInitialized = true;
  }

  /// Xin quyền gửi thông báo (Android và iOS)
  Future<void> requestPermissions() async {
    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }

    final iosImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (iosImplementation != null) {
      await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  /// Khởi tạo 2 Channel riêng biệt để phát 2 âm thanh khác nhau trên Android
  Future<void> _createNotificationChannels() async {
    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImplementation == null) return;

    // 1. Channel khi có di chuyển (âm thanh motion_detected)
    const AndroidNotificationChannel movingChannel = AndroidNotificationChannel(
      'motion_channel_moving_v2',
      'Có chuyển động',
      description: 'Phát âm thanh khi thiết bị phát hiện có di chuyển',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('motion_detected'),
      enableVibration: true,
    );

    // 2. Channel khi dừng di chuyển (âm thanh motion_stopped)
    const AndroidNotificationChannel stoppedChannel =
        AndroidNotificationChannel(
          'motion_channel_stopped_v2',
          'Dừng chuyển động',
          description: 'Phát âm thanh khi thiết bị phát hiện dừng di chuyển',
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('motion_stopped'),
          enableVibration: true,
        );

    await androidImplementation.createNotificationChannel(movingChannel);
    await androidImplementation.createNotificationChannel(stoppedChannel);
  }

  /// Bắn thông báo tương ứng với trạng thái di chuyển / không di chuyển
  Future<void> showMovementNotification({required bool isMoving}) async {
    final int notificationId = 1001;

    final String title = 'Demo';
    final String body = isMoving ? 'Có chuyển động' : 'Dừng chuyển động';

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          isMoving ? 'motion_channel_moving_v2' : 'motion_channel_stopped_v2',
          isMoving ? 'Có chuyển động' : 'Dừng chuyển động',
          channelDescription: isMoving
              ? 'Phát âm thanh khi thiết bị phát hiện có di chuyển'
              : 'Phát âm thanh khi thiết bị phát hiện dừng di chuyển',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(
            isMoving ? 'motion_detected' : 'motion_stopped',
          ),
          enableVibration: true,
          onlyAlertOnce: false,
        );

    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: isMoving ? 'motion_detected.wav' : 'motion_stopped.wav',
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      // Hủy thông báo cũ để Android xem đây là thông báo mới hoàn toàn,
      // luôn bung banner nổi (Heads-up) và đổ chuông mỗi lần đổi trạng thái.
      await _plugin.cancel(id: notificationId);
      await _plugin.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
      );
    } catch (e) {
      // Bỏ qua hoặc ghi log nếu có lỗi
    }
  }
}
