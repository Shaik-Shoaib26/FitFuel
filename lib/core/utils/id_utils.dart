import 'dart:math';

class IdUtils {
  static String generateId() {
    final random = Random();
    final time = DateTime.now().microsecondsSinceEpoch;
    final randVal = random.nextInt(1000000);
    return '${time}_$randVal';
  }
}
