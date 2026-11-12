// User model for SUP FUN application
// Plain data class with JSON serialization - stored as JSON string in Hive
class AppUser {
  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final String? localAvatarPath;
  final String? city;
  final String? bio;
  final int level;
  final String rank;
  final int experience;
  final int experienceToNext;
  final double totalDistance;
  final int totalTrips;
  final int daysOnWater;
  final DateTime? registeredAt;
  final DateTime? lastSyncAt;
  final bool isVerified;
  final String? phone;

  AppUser({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    this.localAvatarPath,
    this.city,
    this.bio,
    this.level = 1,
    this.rank = 'Новичок',
    this.experience = 0,
    this.experienceToNext = 100,
    this.totalDistance = 0.0,
    this.totalTrips = 0,
    this.daysOnWater = 0,
    this.registeredAt,
    this.lastSyncAt,
    this.isVerified = false,
    this.phone,
  });

  double get experienceProgress =>
      experienceToNext > 0 ? experience / experienceToNext : 0.0;

  /// Create from API JSON
  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id']?.toString() ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      avatarUrl: json['avatarUrl'],
      localAvatarPath: json['localAvatarPath'],
      city: json['city'],
      bio: json['bio'],
      level: (json['level'] ?? 1) as int,
      rank: json['rank'] ?? 'Новичок',
      experience: (json['experience'] ?? 0) as int,
      experienceToNext: (json['experienceToNext'] ?? 100) as int,
      totalDistance: ((json['totalDistance'] ?? 0) as num).toDouble(),
      totalTrips: (json['totalTrips'] ?? 0) as int,
      daysOnWater: (json['daysOnWater'] ?? 0) as int,
      registeredAt: json['registeredAt'] != null
          ? DateTime.tryParse(json['registeredAt'].toString())
          : null,
      lastSyncAt: json['lastSyncAt'] != null
          ? DateTime.tryParse(json['lastSyncAt'].toString())
          : null,
      isVerified: json['isVerified'] == true,
      phone: json['phone'],
    );
  }

  /// Convert to JSON for API sync
  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'avatarUrl': avatarUrl,
        'localAvatarPath': localAvatarPath,
        'city': city,
        'bio': bio,
        'level': level,
        'rank': rank,
        'experience': experience,
        'experienceToNext': experienceToNext,
        'totalDistance': totalDistance,
        'totalTrips': totalTrips,
        'daysOnWater': daysOnWater,
        'registeredAt': registeredAt?.toIso8601String(),
        'lastSyncAt': lastSyncAt?.toIso8601String(),
        'isVerified': isVerified,
        'phone': phone,
      };

  AppUser copyWith({
    String? name,
    String? email,
    String? avatarUrl,
    String? localAvatarPath,
    String? city,
    String? bio,
    int? level,
    String? rank,
    int? experience,
    int? experienceToNext,
    double? totalDistance,
    int? totalTrips,
    int? daysOnWater,
    DateTime? lastSyncAt,
    bool? isVerified,
    String? phone,
  }) {
    return AppUser(
      id: id,
      email: email ?? this.email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      localAvatarPath: localAvatarPath ?? this.localAvatarPath,
      city: city ?? this.city,
      bio: bio ?? this.bio,
      level: level ?? this.level,
      rank: rank ?? this.rank,
      experience: experience ?? this.experience,
      experienceToNext: experienceToNext ?? this.experienceToNext,
      totalDistance: totalDistance ?? this.totalDistance,
      totalTrips: totalTrips ?? this.totalTrips,
      daysOnWater: daysOnWater ?? this.daysOnWater,
      registeredAt: registeredAt,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      isVerified: isVerified ?? this.isVerified,
      phone: phone ?? this.phone,
    );
  }
}
