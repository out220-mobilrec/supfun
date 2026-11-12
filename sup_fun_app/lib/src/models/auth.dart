class SessionUser {
  SessionUser({
    required this.id,
    required this.email,
    required this.name,
    this.phone,
    this.city,
    this.region,
    this.country,
    this.avatarUrl,
    this.bio,
    this.homeWaterBodyId,
    this.role = 'user',
    this.isBanned = false,
    this.xp = 0,
    this.isEmailVerified = false,
    this.locale = 'ru',
    this.profileVisibility = 'public',
    this.activityVisibility = 'public',
    this.geoVisibility = 'private',
    this.showOnline = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String email;
  final String name;
  final String? phone;
  final String? city;
  final String? region;
  final String? country;
  final String? avatarUrl;
  final String? bio;
  final String? homeWaterBodyId;
  final String role;
  final bool isBanned;
  final int xp;
  final bool isEmailVerified;
  /// Язык интерфейса профиля: ru (по умолчанию) | en.
  final String locale;
  final String profileVisibility;
  final String activityVisibility;
  final String geoVisibility;
  final bool showOnline;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String? get homeWaterBodyName => null;

  factory SessionUser.fromJson(Map<String, dynamic> j) => SessionUser(
        id: j['id'] as String,
        email: (j['email'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        phone: j['phone'] as String?,
        city: j['city'] as String?,
        region: j['region'] as String?,
        country: j['country'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
        bio: j['bio'] as String?,
        homeWaterBodyId: j['homeWaterBodyId'] as String?,
        role: (j['role'] ?? 'user') as String,
        isBanned: (j['isBanned'] ?? false) as bool,
        xp: (j['xp'] ?? 0) as int,
        isEmailVerified: (j['isEmailVerified'] ?? false) as bool,
        locale: j['locale'] == 'en' ? 'en' : 'ru',
        profileVisibility: (j['profileVisibility'] ?? 'public') as String,
        activityVisibility: (j['activityVisibility'] ?? 'public') as String,
        geoVisibility: (j['geoVisibility'] ?? 'private') as String,
        showOnline: (j['showOnline'] ?? true) as bool,
        createdAt: _dt(j['createdAt']),
        updatedAt: _dt(j['updatedAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'phone': phone,
        'city': city,
        'region': region,
        'country': country,
        'avatarUrl': avatarUrl,
        'bio': bio,
        'homeWaterBodyId': homeWaterBodyId,
        'role': role,
        'isBanned': isBanned,
        'xp': xp,
        'isEmailVerified': isEmailVerified,
        'locale': locale,
        'profileVisibility': profileVisibility,
        'activityVisibility': activityVisibility,
        'geoVisibility': geoVisibility,
        'showOnline': showOnline,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  SessionUser copyWith({
    String? name,
    String? phone,
    String? city,
    String? region,
    String? country,
    String? avatarUrl,
    String? bio,
    String? homeWaterBodyId,
    String? locale,
    String? profileVisibility,
    String? activityVisibility,
    String? geoVisibility,
    bool? showOnline,
    int? xp,
  }) =>
      SessionUser(
        id: id,
        email: email,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        city: city ?? this.city,
        region: region ?? this.region,
        country: country ?? this.country,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        bio: bio ?? this.bio,
        homeWaterBodyId: homeWaterBodyId ?? this.homeWaterBodyId,
        role: role,
        isBanned: isBanned,
        xp: xp ?? this.xp,
        isEmailVerified: isEmailVerified,
        locale: locale ?? this.locale,
        profileVisibility: profileVisibility ?? this.profileVisibility,
        activityVisibility: activityVisibility ?? this.activityVisibility,
        geoVisibility: geoVisibility ?? this.geoVisibility,
        showOnline: showOnline ?? this.showOnline,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  static DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toUtc();
}

class AuthResult {
  final String accessToken;
  final String refreshToken;
  final SessionUser user;

  AuthResult({required this.accessToken, required this.refreshToken, required this.user});

  factory AuthResult.fromJson(Map<String, dynamic> j) => AuthResult(
        accessToken: j['accessToken'] as String,
        refreshToken: j['refreshToken'] as String,
        user: SessionUser.fromJson(Map<String, dynamic>.from(j['user'])),
      );
}

class MessageResult {
  final bool ok;
  final String? devToken;

  MessageResult({required this.ok, this.devToken});

  factory MessageResult.fromJson(Map<String, dynamic> j) => MessageResult(
        ok: (j['ok'] ?? false) as bool,
        devToken: j['devToken'] as String?,
      );
}