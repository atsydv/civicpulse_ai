import 'package:flutter/material.dart';

import '../../../core/app_export.dart';
import '../../../core/services/notification_service.dart';

class NotificationPanelWidget extends StatefulWidget {
  final int userId;
  final VoidCallback onClose;

  const NotificationPanelWidget({
    super.key,
    required this.userId,
    required this.onClose,
  });

  @override
  State<NotificationPanelWidget> createState() =>
      _NotificationPanelWidgetState();
}

class _NotificationPanelWidgetState extends State<NotificationPanelWidget> {
  late List<AppNotification> _notifications;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() {
    setState(() {
      _notifications = NotificationService.instance.getNotificationsForUser(
        widget.userId,
      );
    });
  }

  void _markAllRead() {
    NotificationService.instance.markAllRead(widget.userId);
    _loadNotifications();
  }

  Color _notifColor(NotificationType type) {
    switch (type) {
      case NotificationType.newReport:
        return AppTheme.critical;
      case NotificationType.taskAssigned:
        return AppTheme.primary;
      case NotificationType.reportResolved:
        return AppTheme.success;
    }
  }

  String _notifIcon(NotificationType type) {
    switch (type) {
      case NotificationType.newReport:
        return 'report_problem';
      case NotificationType.taskAssigned:
        return 'engineering';
      case NotificationType.reportResolved:
        return 'check_circle_outline';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 420),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(20), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(100),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                const CustomIconWidget(
                  iconName: 'notifications',
                  color: AppTheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Notifications',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                if (_notifications.any((n) => !n.isRead))
                  GestureDetector(
                    onTap: _markAllRead,
                    child: Text(
                      'Mark all read',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: widget.onClose,
                  child: const CustomIconWidget(
                    iconName: 'close',
                    color: Color(0xFF64748B),
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: Colors.white.withAlpha(13)),
          // Notification list
          _notifications.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const CustomIconWidget(
                        iconName: 'notifications_none',
                        color: Color(0xFF64748B),
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No notifications yet',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                )
              : Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) =>
                        Container(height: 1, color: Colors.white.withAlpha(8)),
                    itemBuilder: (context, index) {
                      final notif = _notifications[index];
                      final color = _notifColor(notif.type);
                      return GestureDetector(
                        onTap: () {
                          NotificationService.instance.markRead(notif.id);
                          _loadNotifications();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          color: notif.isRead
                              ? Colors.transparent
                              : color.withAlpha(15),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: color.withAlpha(30),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: CustomIconWidget(
                                    iconName: _notifIcon(notif.type),
                                    color: color,
                                    size: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            notif.title,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        if (!notif.isRead)
                                          Container(
                                            width: 7,
                                            height: 7,
                                            decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      notif.body,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        color: const Color(0xFF94A3B8),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      notif.timeAgo,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }
}
