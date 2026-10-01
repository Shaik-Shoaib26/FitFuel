import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitfuel/features/authentication/presentation/providers/auth_providers.dart';
import 'package:fitfuel/features/profile/domain/entities/nutrition_goals_entity.dart';
import 'package:fitfuel/features/profile/domain/entities/user_profile_entity.dart';
import 'package:fitfuel/features/profile/presentation/providers/profile_providers.dart';
import 'package:fitfuel/features/profile/presentation/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'test_uid';
  @override
  String get email => 'test@example.com';
  @override
  String get displayName => 'Tester User';
}

void main() {
  testWidgets('ProfileScreen renders correct settings shortcuts without duplicate goals', (tester) async {
    final profile = UserProfileEntity(
      uid: 'test_uid',
      email: 'test@example.com',
      displayName: 'Tester User',
      age: 28,
      gender: 'male',
      height: 175,
      weight: 70,
      activityLevel: 'moderate',
      fitnessGoal: 'maintain',
      dietaryPreference: 'none',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final goals = NutritionGoalsEntity(
      userId: 'test_uid',
      dailyCalorieTarget: 2000,
      proteinTargetGrams: 150,
      carbsTargetGrams: 200,
      fatTargetGrams: 65,
      updatedAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateStreamProvider.overrideWith((ref) => Stream.value(_FakeUser())),
          currentProfileStreamProvider.overrideWith((ref) => Stream.value(profile)),
          nutritionGoalsStreamProvider.overrideWith((ref) => Stream.value(goals)),
        ],
        child: const MaterialApp(
          home: ProfileScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify exactly one Health Profile & Goals entry
    expect(find.text('Health Profile & Goals'), findsOneWidget);

    // Verify Preferences, Reminders, and Account navigation shortcuts exist
    expect(find.text('Preferences'), findsOneWidget);
    expect(find.text('Reminders'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);

    // Confirm duplicate "Goals & Preferences" shortcut is removed
    expect(find.text('Goals & Preferences'), findsNothing);
  });
}
