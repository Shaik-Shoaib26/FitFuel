import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reminder_settings_model.dart';

abstract class IRemindersRemoteDataSource {
  Future<ReminderSettingsModel?> getSettings(String uid);
  Future<void> saveSettings(String uid, ReminderSettingsModel settings);
  Stream<ReminderSettingsModel?> streamSettings(String uid);
}

class RemindersRemoteDataSourceImpl implements IRemindersRemoteDataSource {
  final FirebaseFirestore _firestore;

  RemindersRemoteDataSourceImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<ReminderSettingsModel?> getSettings(String uid) async {
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('reminderSettings')
        .doc('settings')
        .get();
    if (!doc.exists || doc.data() == null) return null;
    return ReminderSettingsModel.fromFirestore(doc);
  }

  @override
  Future<void> saveSettings(String uid, ReminderSettingsModel settings) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('reminderSettings')
        .doc('settings')
        .set(settings.toFirestore(), SetOptions(merge: true));
  }

  @override
  Stream<ReminderSettingsModel?> streamSettings(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('reminderSettings')
        .doc('settings')
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return ReminderSettingsModel.fromFirestore(doc);
    });
  }
}
