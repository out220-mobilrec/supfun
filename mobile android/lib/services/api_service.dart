// API service for SUP FUN backend
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:3000/api';
  static String? _authToken;

  static void setAuthToken(String? token) {
    _authToken = token;
  }

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  // Auth
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
      }),
    );
    return _handleResponse(response);
  }

  // Waterbodies
  static Future<List<WaterBody>> getWaterBodies({
    String? city,
    double? lat,
    double? lng,
    double radius = 50,
  }) async {
    final queryParams = <String, String>{};
    if (city != null) queryParams['city'] = city;
    if (lat != null) queryParams['lat'] = lat.toString();
    if (lng != null) queryParams['lng'] = lng.toString();
    queryParams['radius'] = radius.toString();

    final uri = Uri.parse('$baseUrl/waterbodies')
        .replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _headers);
    final data = _handleResponse(response);

    final list = data['items'] as List<dynamic>? ?? [];
    return list
        .map((e) => WaterBody.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<WaterBody> getWaterBody(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/waterbodies/$id'),
      headers: _headers,
    );
    final data = _handleResponse(response);
    return WaterBody.fromJson(data);
  }

  // Events
  static Future<List<SupEvent>> getEvents({String? waterBodyId}) async {
    final queryParams = <String, String>{};
    if (waterBodyId != null) queryParams['waterBodyId'] = waterBodyId;

    final uri = Uri.parse('$baseUrl/events')
        .replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _headers);
    final data = _handleResponse(response);

    final list = data['items'] as List<dynamic>? ?? [];
    return list
        .map((e) => SupEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<SupEvent> createEvent(Map<String, dynamic> eventData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/events'),
      headers: _headers,
      body: jsonEncode(eventData),
    );
    final data = _handleResponse(response);
    return SupEvent.fromJson(data);
  }

  // Trips
  static Future<List<Trip>> getUserTrips(String userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId/trips'),
      headers: _headers,
    );
    final data = _handleResponse(response);

    final list = data['items'] as List<dynamic>? ?? [];
    return list
        .map((e) => Trip.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Trip> saveTrip(Map<String, dynamic> tripData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/trips'),
      headers: _headers,
      body: jsonEncode(tripData),
    );
    final data = _handleResponse(response);
    return Trip.fromJson(data);
  }

  // Marketplace
  static Future<List<Listing>> getListings({
    String? category,
    String? city,
  }) async {
    final queryParams = <String, String>{};
    if (category != null) queryParams['category'] = category;
    if (city != null) queryParams['city'] = city;

    final uri = Uri.parse('$baseUrl/marketplace/listings')
        .replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _headers);
    final data = _handleResponse(response);

    final list = data['items'] as List<dynamic>? ?? [];
    return list
        .map((e) => Listing.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // User profile
  static Future<User> getUserProfile(String userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId'),
      headers: _headers,
    );
    final data = _handleResponse(response);
    return User.fromJson(data);
  }

  // Weather
  static Future<WeatherInfo> getWeather(double lat, double lng) async {
    final response = await http.get(
      Uri.parse('$baseUrl/weather?lat=$lat&lng=$lng'),
      headers: _headers,
    );
    final data = _handleResponse(response);
    return WeatherInfo.fromJson(data);
  }

  // Feed
  static Future<List<Map<String, dynamic>>> getFeed({int page = 1}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/feed?page=$page'),
      headers: _headers,
    );
    final data = _handleResponse(response);

    final list = data['items'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw ApiException(
        'Request failed: ${response.statusCode}',
        statusCode: response.statusCode,
        body: response.body,
      );
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  final String body;

  ApiException(this.message, {required this.statusCode, required this.body});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
