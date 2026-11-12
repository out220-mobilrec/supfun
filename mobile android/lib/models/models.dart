// Data models for SUP FUN application

// User model
class User {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final String? city;
  final DateTime? registeredAt;
  final int totalTrips;
  final double totalDistance;
  final List<String> achievements;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.city,
    this.registeredAt,
    this.totalTrips = 0,
    this.totalDistance = 0,
    this.achievements = const [],
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        avatarUrl: json['avatarUrl'] as String?,
        city: json['city'] as String?,
        registeredAt: json['registeredAt'] != null
            ? DateTime.parse(json['registeredAt'] as String)
            : null,
        totalTrips: json['totalTrips'] as int? ?? 0,
        totalDistance: (json['totalDistance'] as num?)?.toDouble() ?? 0,
        achievements:
            (json['achievements'] as List<dynamic>?)?.cast<String>() ?? [],
      );
}

// Water body model (lake, river, sea)
class WaterBody {
  final String id;
  final String name;
  final String type; // lake, river, sea
  final String city;
  final double latitude;
  final double longitude;
  final String? description;
  final double? temperature;
  final String? weatherCondition;
  final double rating;
  final int ratingsCount;
  final String? imageUrl;
  final List<String> features;

  WaterBody({
    required this.id,
    required this.name,
    required this.type,
    required this.city,
    required this.latitude,
    required this.longitude,
    this.description,
    this.temperature,
    this.weatherCondition,
    this.rating = 0,
    this.ratingsCount = 0,
    this.imageUrl,
    this.features = const [],
  });

  factory WaterBody.fromJson(Map<String, dynamic> json) => WaterBody(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
        city: json['city'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        description: json['description'] as String?,
        temperature: (json['temperature'] as num?)?.toDouble(),
        weatherCondition: json['weatherCondition'] as String?,
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        ratingsCount: json['ratingsCount'] as int? ?? 0,
        imageUrl: json['imageUrl'] as String?,
        features: (json['features'] as List<dynamic>?)?.cast<String>() ?? [],
      );
}

// SUP Trip/Session model
class Trip {
  final String id;
  final String userId;
  final String waterBodyId;
  final String? waterBodyName;
  final DateTime startedAt;
  final DateTime? endedAt;
  final double distance; // in km
  final Duration duration;
  final double? maxSpeed; // km/h
  final double? avgSpeed;
  final List<TripPoint> route;
  final TripStatus status;
  final String? notes;

  Trip({
    required this.id,
    required this.userId,
    required this.waterBodyId,
    this.waterBodyName,
    required this.startedAt,
    this.endedAt,
    this.distance = 0,
    this.duration = Duration.zero,
    this.maxSpeed,
    this.avgSpeed,
    this.route = const [],
    this.status = TripStatus.planned,
    this.notes,
  });

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
        id: json['id'] as String,
        userId: json['userId'] as String,
        waterBodyId: json['waterBodyId'] as String,
        waterBodyName: json['waterBodyName'] as String?,
        startedAt: DateTime.parse(json['startedAt'] as String),
        endedAt: json['endedAt'] != null
            ? DateTime.parse(json['endedAt'] as String)
            : null,
        distance: (json['distance'] as num?)?.toDouble() ?? 0,
        duration: Duration(seconds: json['durationSeconds'] as int? ?? 0),
        maxSpeed: (json['maxSpeed'] as num?)?.toDouble(),
        avgSpeed: (json['avgSpeed'] as num?)?.toDouble(),
        route: (json['route'] as List<dynamic>?)
                ?.map((e) => TripPoint.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        status: TripStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => TripStatus.planned,
        ),
        notes: json['notes'] as String?,
      );
}

enum TripStatus { planned, active, completed, cancelled }

// Trip point for GPS tracking
class TripPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? speed;
  final double? altitude;

  TripPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.speed,
    this.altitude,
  });

  factory TripPoint.fromJson(Map<String, dynamic> json) => TripPoint(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp'] as String),
        speed: (json['speed'] as num?)?.toDouble(),
        altitude: (json['altitude'] as num?)?.toDouble(),
      );
}

// Event model
class SupEvent {
  final String id;
  final String title;
  final String description;
  final String waterBodyId;
  final String? waterBodyName;
  final String organizerId;
  final String? organizerName;
  final DateTime startsAt;
  final DateTime? endsAt;
  final int maxParticipants;
  final int currentParticipants;
  final EventType type;
  final String? imageUrl;
  final double? price;
  final String difficulty; // easy, medium, hard

  SupEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.waterBodyId,
    this.waterBodyName,
    required this.organizerId,
    this.organizerName,
    required this.startsAt,
    this.endsAt,
    this.maxParticipants = 0,
    this.currentParticipants = 0,
    required this.type,
    this.imageUrl,
    this.price,
    this.difficulty = 'easy',
  });

  factory SupEvent.fromJson(Map<String, dynamic> json) => SupEvent(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        waterBodyId: json['waterBodyId'] as String,
        waterBodyName: json['waterBodyName'] as String?,
        organizerId: json['organizerId'] as String,
        organizerName: json['organizerName'] as String?,
        startsAt: DateTime.parse(json['startsAt'] as String),
        endsAt: json['endsAt'] != null
            ? DateTime.parse(json['endsAt'] as String)
            : null,
        maxParticipants: json['maxParticipants'] as int? ?? 0,
        currentParticipants: json['currentParticipants'] as int? ?? 0,
        type: EventType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => EventType.individual,
        ),
        imageUrl: json['imageUrl'] as String?,
        price: (json['price'] as num?)?.toDouble(),
        difficulty: json['difficulty'] as String? ?? 'easy',
      );
}

enum EventType { individual, group, training, competition }

// Marketplace listing
class Listing {
  final String id;
  final String title;
  final String description;
  final String category; // sup, paddle, accessory
  final double price;
  final String currency;
  final String sellerId;
  final String? sellerName;
  final List<String> imageUrls;
  final String condition; // new, used
  final String city;
  final DateTime postedAt;
  final ListingStatus status;

  Listing({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    this.currency = 'RUB',
    required this.sellerId,
    this.sellerName,
    this.imageUrls = const [],
    this.condition = 'used',
    required this.city,
    required this.postedAt,
    this.status = ListingStatus.active,
  });

  factory Listing.fromJson(Map<String, dynamic> json) => Listing(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        category: json['category'] as String,
        price: (json['price'] as num).toDouble(),
        currency: json['currency'] as String? ?? 'RUB',
        sellerId: json['sellerId'] as String,
        sellerName: json['sellerName'] as String?,
        imageUrls:
            (json['imageUrls'] as List<dynamic>?)?.cast<String>() ?? [],
        condition: json['condition'] as String? ?? 'used',
        city: json['city'] as String,
        postedAt: DateTime.parse(json['postedAt'] as String),
        status: ListingStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => ListingStatus.active,
        ),
      );
}

enum ListingStatus { active, sold, archived }

// Weather info
class WeatherInfo {
  final double temperature;
  final String condition; // sunny, cloudy, rainy
  final double windSpeed;
  final String windDirection;
  final double? humidity;
  final double? pressure;

  WeatherInfo({
    required this.temperature,
    required this.condition,
    required this.windSpeed,
    required this.windDirection,
    this.humidity,
    this.pressure,
  });

  factory WeatherInfo.fromJson(Map<String, dynamic> json) => WeatherInfo(
        temperature: (json['temperature'] as num).toDouble(),
        condition: json['condition'] as String,
        windSpeed: (json['windSpeed'] as num).toDouble(),
        windDirection: json['windDirection'] as String,
        humidity: (json['humidity'] as num?)?.toDouble(),
        pressure: (json['pressure'] as num?)?.toDouble(),
      );
}
