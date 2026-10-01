import '../../core/constants/app_icons.dart';
import 'package:flutter/material.dart';

class AppDestination {
  final String label;
  final String path;
  final IconData icon;
  const AppDestination(this.label, this.path, this.icon);
}

const appDestinations = [
  AppDestination('Home', '/home', AppIcons.home),
  AppDestination('Health', '/health', AppIcons.health),
  AppDestination('Nutrition', '/nutrition', AppIcons.nutrition),
  AppDestination('Plan', '/plan', AppIcons.plan),
  AppDestination('Progress', '/progress', AppIcons.progress),
  AppDestination('AI Coach', '/ai', AppIcons.ai),
];

String parentLocation(String path) {
  if (path.startsWith('/settings/')) return '/settings';
  if (path == '/settings' || path == '/profile' || path == '/ai') {
    return '/home';
  }
  if (path.startsWith('/nutrition/food/') ||
      path.startsWith('/nutrition/custom/')) {
    return '/nutrition/search';
  }
  if (path.startsWith('/nutrition/')) return '/nutrition';
  if (path == '/plan/grocery/pantry') return '/plan/grocery';
  if (path.startsWith('/plan/')) return '/plan';
  if (path.startsWith('/health/')) return '/health';
  if (path.startsWith('/progress/insights/')) return '/progress/insights';
  if (path.startsWith('/progress/analytics/')) return '/progress/analytics';
  if (path.startsWith('/progress/')) return '/progress';
  return '/home';
}
