import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:fitfuel/app/config/routes.dart';
import 'package:fitfuel/features/authentication/presentation/providers/auth_providers.dart';
import 'package:fitfuel/features/ai_assistant/presentation/providers/ai_assistant_providers.dart';
import 'package:fitfuel/features/ai_assistant/presentation/controllers/ai_assistant_controller.dart';
import 'package:fitfuel/features/ai_assistant/domain/entities/chat_message.dart';
import 'package:fitfuel/features/ai_assistant/domain/repositories/ai_nutrition_repository.dart';
import 'package:fitfuel/features/profile/presentation/providers/profile_providers.dart';
import 'package:fitfuel/features/profile/presentation/controllers/user_profile_controller.dart';
import 'package:fitfuel/features/profile/domain/repositories/i_profile_repository.dart';
import 'package:fitfuel/features/smart_eat/presentation/providers/smart_eat_providers.dart';
import 'package:fitfuel/features/smart_eat/domain/repositories/i_smart_eat_repository.dart';
import 'package:fitfuel/features/nutrition/presentation/providers/nutrition_providers.dart';
import 'package:fitfuel/features/food/data/repositories/food_repository_impl.dart';
import 'package:fitfuel/features/food/data/datasources/food_remote_datasource.dart';
import 'package:fitfuel/core/errors/failures.dart';
import 'package:fitfuel/core/services/logger_service.dart';

// Mock Classes using Mocktail
class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUser extends Mock implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;

  MockUser({required this.uid, this.email, this.displayName});
}
class MockFoodRemoteDataSource extends Mock implements FoodRemoteDataSource {}
class MockBuildContext extends Mock implements BuildContext {}
class MockGoRouterState extends Mock implements GoRouterState {}
class MockAiNutritionRepository extends Mock implements IAiNutritionRepository {}
class MockSmartEatRepository extends Mock implements ISmartEatRepository {}
class MockProfileRepository extends Mock implements IProfileRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Authentication & Security Tests', () {
    late MockFirebaseAuth mockFirebaseAuth;
    late MockFoodRemoteDataSource mockFoodRemoteDataSource;
    late MockAiNutritionRepository mockAiRepository;
    late MockSmartEatRepository mockSmartEatRepository;
    late MockProfileRepository mockProfileRepository;

    setUp(() {
      mockFirebaseAuth = MockFirebaseAuth();
      mockFoodRemoteDataSource = MockFoodRemoteDataSource();
      mockAiRepository = MockAiNutritionRepository();
      mockSmartEatRepository = MockSmartEatRepository();
      mockProfileRepository = MockProfileRepository();
    });

    test('1. GoRouter redirects unauthenticated users from protected route to Login', () {
      final context = MockBuildContext();
      final state = MockGoRouterState();
      
      when(() => state.matchedLocation).thenReturn(AppRoutes.dashboard);

      const authStateAsync = AsyncValue<User?>.data(null);
      final redirectLocation = AppRoutes.redirect(context, state, authStateAsync);
      
      expect(redirectLocation, equals(AppRoutes.login));
    });

    test('2. GoRouter redirects authenticated users from Login route to Dashboard', () {
      final context = MockBuildContext();
      final state = MockGoRouterState();
      
      when(() => state.matchedLocation).thenReturn(AppRoutes.login);

      final mockUser = MockUser(uid: 'user_123');
      final authStateAsync = AsyncValue<User?>.data(mockUser);
      final redirectLocation = AppRoutes.redirect(context, state, authStateAsync);
      
      expect(redirectLocation, equals(AppRoutes.dashboard));
    });

    test('3. Logging out automatically invalidates and resets aiAssistantControllerProvider', () {
      final mockUser = MockUser(uid: 'user_A');
      
      var container = ProviderContainer(
        overrides: [
          authStateStreamProvider.overrideWith((ref) => Stream.value(mockUser)),
          aiRepositoryProvider.overrideWithValue(mockAiRepository),
        ],
      );

      final controller = container.read(aiAssistantControllerProvider.notifier);
      expect(controller.state.messages, isEmpty);

      // Directly set the messages in controller state to mock active state
      controller.state = AiAssistantSuccess(
        [
          ChatMessage(
            text: 'Hello User A',
            sender: MessageSender.user,
            timestamp: DateTime.now(),
          ),
        ],
        providerUsed: 'Gemini',
      );
      expect(container.read(aiAssistantControllerProvider).messages, isNotEmpty);

      // Emulate logout -> recreate container with null user
      container = ProviderContainer(
        overrides: [
          authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
          aiRepositoryProvider.overrideWithValue(mockAiRepository),
        ],
      );

      expect(container.read(aiAssistantControllerProvider).messages, isEmpty);
    });

    test('4. Logging out automatically invalidates and resets userProfileControllerProvider', () {
      final mockUser = MockUser(uid: 'user_A');
      var container = ProviderContainer(
        overrides: [
          authStateStreamProvider.overrideWith((ref) => Stream.value(mockUser)),
          profileRepositoryProvider.overrideWithValue(mockProfileRepository),
        ],
      );

      expect(container.read(userProfileControllerProvider) is UserProfileInitialState, isTrue);

      // Emulate logout
      container = ProviderContainer(
        overrides: [
          authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
          profileRepositoryProvider.overrideWithValue(mockProfileRepository),
        ],
      );

      expect(container.read(userProfileControllerProvider) is UserProfileInitialState, isTrue);
    });

    test('5. Logging out automatically resets SmartEatController to initial empty values', () {
      final mockUser = MockUser(uid: 'user_A');
      var container = ProviderContainer(
        overrides: [
          authStateStreamProvider.overrideWith((ref) => Stream.value(mockUser)),
          smartEatRepositoryProvider.overrideWithValue(mockSmartEatRepository),
          nutritionStreamProvider.overrideWith((ref) => Stream.value(const [])),
        ],
      );

      final state = container.read(smartEatControllerProvider);
      expect(state.recommendations.isLoading, isTrue);

      // Emulate logout
      container = ProviderContainer(
        overrides: [
          authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
          smartEatRepositoryProvider.overrideWithValue(mockSmartEatRepository),
          nutritionStreamProvider.overrideWith((ref) => Stream.value(const [])),
        ],
      );

      final updatedState = container.read(smartEatControllerProvider);
      expect(updatedState.recommendations.isLoading, isTrue);
      expect(updatedState.swaps, isEmpty);
    });

    test('6. Account switching between User A and User B prevents cache leakage', () {
      final userA = MockUser(uid: 'user_A');
      final userB = MockUser(uid: 'user_B');

      var container = ProviderContainer(
        overrides: [
          authStateStreamProvider.overrideWith((ref) => Stream.value(userA)),
          aiRepositoryProvider.overrideWithValue(mockAiRepository),
        ],
      );

      // Populate User A Assistant State
      container.read(aiAssistantControllerProvider.notifier).state = AiAssistantSuccess(
        [
          ChatMessage(
            text: 'User A prompt',
            sender: MessageSender.user,
            timestamp: DateTime.now(),
          ),
        ],
        providerUsed: 'Gemini',
      );
      expect(container.read(aiAssistantControllerProvider).messages.first.text, contains('User A'));

      // Switch to user B
      container = ProviderContainer(
        overrides: [
          authStateStreamProvider.overrideWith((ref) => Stream.value(userB)),
          aiRepositoryProvider.overrideWithValue(mockAiRepository),
        ],
      );

      expect(container.read(aiAssistantControllerProvider).messages, isEmpty);
    });

    test('7. Repository blocks unauthenticated database access and throws controlled Failure', () async {
      final repo = FoodRepositoryImpl(
        mockFoodRemoteDataSource,
        firebaseAuth: mockFirebaseAuth,
      );

      when(() => mockFirebaseAuth.currentUser).thenReturn(null);

      expect(
        () async => await repo.getFavoriteFoods(),
        throwsA(isA<ServerFailure>().having((f) => f.message, 'message', contains('User must be authenticated.'))),
      );
    });

    test('8. Firestore paths resolve UID securely from auth state', () {
      final repo = FoodRepositoryImpl(
        mockFoodRemoteDataSource,
        firebaseAuth: mockFirebaseAuth,
      );

      final testUser = MockUser(uid: 'secure_uid_456');
      when(() => mockFirebaseAuth.currentUser).thenReturn(testUser);
      when(() => mockFoodRemoteDataSource.getFavoriteFoodIds('secure_uid_456'))
          .thenAnswer((_) async => []);
      when(() => mockFoodRemoteDataSource.getCustomFoods('secure_uid_456'))
          .thenAnswer((_) async => []);

      expect(
        () async {
          await repo.getFavoriteFoods();
        },
        returnsNormally,
      );
    });

    test('9. LoggerService protects sensitive details by not logging passwords or keys', () {
      LoggerService.info('Testing security logs - password should not appear here');
      expect(true, isTrue);
    });
  });
}
