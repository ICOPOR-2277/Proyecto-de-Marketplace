import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/app_state.dart';

class NotificationsDialog extends StatelessWidget {
  const NotificationsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: notificationState,
      builder: (context, _) {
        final notifications = notificationState.notifications;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: 440,
            constraints: const BoxConstraints(maxHeight: 520),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications_active, color: kNavy),
                    const SizedBox(width: 8),
                    const Text(
                      'Notificaciones',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextDark),
                    ),
                    const Spacer(),
                    if (notificationState.unreadCount > 0)
                      TextButton(
                        onPressed: () => notificationState.markAllAsRead(),
                        child: const Text('Marcar leídas', style: TextStyle(fontSize: 12)),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
                const Divider(),
                if (notifications.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text('No tienes notificaciones pendientes', style: TextStyle(color: kTextGrey)),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: notifications.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final notif = notifications[idx];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: notif.read ? Colors.grey.shade200 : kNavy.withOpacity(0.12),
                            child: Icon(
                              Icons.notifications_outlined,
                              color: notif.read ? Colors.grey : kNavy,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            notif.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: notif.read ? FontWeight.normal : FontWeight.bold,
                              color: kTextDark,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(notif.message, style: const TextStyle(fontSize: 12, color: kTextGrey)),
                              const SizedBox(height: 4),
                              Text(
                                '${notif.time.hour.toString().padLeft(2, '0')}:${notif.time.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
