class UserProfileEntity {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final bool emailVerified;
  final int? age;
  final String? gender;
  final double? height;
  final double? weight;
  final String? activityLevel;
  final String? fitnessGoal;
  final String? dietaryPreference;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfileEntity({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.emailVerified = false,
    this.age,
    this.gender,
    this.height,
    this.weight,
    this.activityLevel,
    this.fitnessGoal,
    this.dietaryPreference,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isProfileComplete {
    if (age == null || age! <= 0) return false;
    if (gender == null || gender!.isEmpty || gender == 'unknown') return false;
    if (height == null || height! <= 30) return false;
    if (weight == null || weight! <= 10) return false;
    if (activityLevel == null || activityLevel!.isEmpty || activityLevel == 'unknown') return false;
    if (fitnessGoal == null || fitnessGoal!.isEmpty || fitnessGoal == 'unknown') return false;
    if (dietaryPreference == null || dietaryPreference!.isEmpty || dietaryPreference == 'unknown') return false;
    return true;
  }

  UserProfileEntity copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    bool? emailVerified,
    int? age,
    String? gender,
    double? height,
    double? weight,
    String? activityLevel,
    String? fitnessGoal,
    String? dietaryPreference,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfileEntity(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      emailVerified: emailVerified ?? this.emailVerified,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      activityLevel: activityLevel ?? this.activityLevel,
      fitnessGoal: fitnessGoal ?? this.fitnessGoal,
      dietaryPreference: dietaryPreference ?? this.dietaryPreference,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfileEntity &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          email == other.email &&
          displayName == other.displayName &&
          photoUrl == other.photoUrl &&
          emailVerified == other.emailVerified &&
          age == other.age &&
          gender == other.gender &&
          height == other.height &&
          weight == other.weight &&
          activityLevel == other.activityLevel &&
          fitnessGoal == other.fitnessGoal &&
          dietaryPreference == other.dietaryPreference &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      uid.hashCode ^
      email.hashCode ^
      displayName.hashCode ^
      photoUrl.hashCode ^
      emailVerified.hashCode ^
      age.hashCode ^
      gender.hashCode ^
      height.hashCode ^
      weight.hashCode ^
      activityLevel.hashCode ^
      fitnessGoal.hashCode ^
      dietaryPreference.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;
}
