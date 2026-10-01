import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'network_status.dart';

abstract class ConnectivityService {
  Stream<NetworkStatus> get onStatusChanged;
  Future<NetworkStatus> get currentStatus;
}

class ConnectivityServiceImpl implements ConnectivityService {
  final Connectivity _connectivity;
  final _controller = StreamController<NetworkStatus>.broadcast();

  ConnectivityServiceImpl({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity() {
    try {
      WidgetsBinding.instance;
      _connectivity.onConnectivityChanged.listen((results) {
        final status = _mapResultsToStatus(results);
        _controller.add(status);
      });
    } catch (_) {
      // In non-initialized binding environments (like unit tests), fallback silently
    }
  }

  @override
  Stream<NetworkStatus> get onStatusChanged => _controller.stream;

  @override
  Future<NetworkStatus> get currentStatus async {
    try {
      WidgetsBinding.instance;
      final results = await _connectivity.checkConnectivity();
      return _mapResultsToStatus(results);
    } catch (_) {
      return NetworkStatus.online;
    }
  }

  NetworkStatus _mapResultsToStatus(List<ConnectivityResult> results) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return NetworkStatus.offline;
    }
    return NetworkStatus.online;
  }
}
