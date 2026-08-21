import 'dart:async';

/// In-app notification service for CivicPulse AI
/// Manages notifications for Citizens, Admins, and Workers
class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance =>
      _instance ??= NotificationService._();
  NotificationService._();

  final List<AppNotification> _notifications = [];
  final _controller = StreamController<AppNotification>.broadcast();

  Stream<AppNotification> get notificationStream => _controller.stream;

  List<AppNotification> getNotificationsForUser(int userId) {
    return _notifications
        .where((n) => n.userId == userId)
        .toList()
        .reversed
        .toList();
  }

  int getUnreadCount(int userId) {
    return _notifications.where((n) => n.userId == userId && !n.isRead).length;
  }

  void markAllRead(int userId) {
    for (int i = 0; i < _notifications.length; i++) {
      if (_notifications[i].userId == userId) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
    }
  }

  void markRead(String notificationId) {
    final idx = _notifications.indexWhere((n) => n.id == notificationId);
    if (idx != -1) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
    }
  }

  /// Notify citizen that their report was resolved
  void notifyCitizenReportResolved({
    required int citizenUserId,
    required String ticketId,
    required String category,
  }) {
    final notification = AppNotification(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
      userId: citizenUserId,
      title: '✅ Report Resolved!',
      body:
          'Your $category report ($ticketId) has been resolved. +20 Karma Points awarded!',
      type: NotificationType.reportResolved,
      ticketId: ticketId,
      timestamp: DateTime.now(),
    );
    _addNotification(notification);
  }

  /// Notify admin of a new report submission
  void notifyAdminNewReport({
    required int adminUserId,
    required String ticketId,
    required String category,
    required String severity,
    required String reporterName,
  }) {
    final notification = AppNotification(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}_admin',
      userId: adminUserId,
      title: '🚨 New Report Submitted',
      body:
          '$reporterName submitted a $severity $category report ($ticketId). Requires dispatch.',
      type: NotificationType.newReport,
      ticketId: ticketId,
      timestamp: DateTime.now(),
    );
    _addNotification(notification);
  }

  /// Notify worker of a newly assigned report
  void notifyWorkerAssigned({
    required int workerUserId,
    required String ticketId,
    required String category,
    required String severity,
    required String address,
  }) {
    final notification = AppNotification(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}_worker',
      userId: workerUserId,
      title: '🔧 New Task Assigned',
      body:
          'You have been assigned a $severity $category issue ($ticketId) at $address.',
      type: NotificationType.taskAssigned,
      ticketId: ticketId,
      timestamp: DateTime.now(),
    );
    _addNotification(notification);
  }

  void _addNotification(AppNotification notification) {
    _notifications.insert(0, notification);
    _controller.add(notification);
  }

  void dispose() {
    _controller.close();
  }
}

enum NotificationType { newReport, taskAssigned, reportResolved }

class AppNotification {
  final String id;
  final int userId;
  final String title;
  final String body;
  final NotificationType type;
  final String? ticketId;
  final DateTime timestamp;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.ticketId,
    required this.timestamp,
    this.isRead = false,
  });

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      userId: userId,
      title: title,
      body: body,
      type: type,
      ticketId: ticketId,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
    );
  }

  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
