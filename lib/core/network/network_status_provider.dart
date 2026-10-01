import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'connectivity_service.dart';
import 'network_status.dart';

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityServiceImpl();
});

final networkStatusProvider = StreamProvider<NetworkStatus>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.onStatusChanged;
});

final currentNetworkStatusProvider = FutureProvider<NetworkStatus>((ref) async {
  final service = ref.watch(connectivityServiceProvider);
  return service.currentStatus;
});
