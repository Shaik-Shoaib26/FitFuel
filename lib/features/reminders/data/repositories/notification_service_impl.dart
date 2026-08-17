import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/entities/reminder_entity.dart';
import '../../domain/services/i_notification_service.dart';

class NotificationServiceImpl implements INotificationService {
  final _notificationStreamController = StreamController<Map<String, String>>.broadcast();

  Stream<Map<String, String>> get notificationStream => _notificationStreamController.stream;

  @override
  Future<void> initialize() async {
    debugPrint('Notification Service Initialized');
  }

  @override
  Future<bool> requestPermission() async {
    debugPrint('Notification Permission Requested');
    return true;
  }

  @override
  Future<void> scheduleReminder(ReminderEntity reminder) async {
    debugPrint('Notification Scheduled: ${reminder.title} at ${reminder.scheduledTime}');
  }

  @override
  Future<void> cancelReminder(String id) async {
    debugPrint('Notification Cancelled: $id');
  }

  @override
  Future<void> cancelAllReminders() async {
    debugPrint('All Notifications Cancelled');
  }

  @override
  Future<void> showImmediateNotification(String title, String body) async {
    debugPrint('Immediate Notification: $title - $body');
    _notificationStreamController.add({'title': title, 'body': body});
  }
}
