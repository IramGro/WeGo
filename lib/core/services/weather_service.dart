import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TripWeather {
  final double temp;
  final String description;
  final String icon;
  final String cityName;

  TripWeather({
    required this.temp,
    required this.description,
    required this.icon,
    required this.cityName,
  });

  factory TripWeather.fromJson(Map<String, dynamic> json) {
    final weather = json['weather'][0];
    final main = json['main'];
    return TripWeather(
      temp: (main['temp'] as num).toDouble(),
      description: weather['description'],
      icon: weather['icon'],
      cityName: json['name'],
    );
  }
}

class WeatherService {
  // TODO: Debes obtener una API Key gratuita en https://openweathermap.org/
  // Crea una cuenta, ve a "My API Keys" y pega el código aquí.
  static const String _apiKey = '3b6ca1e29571a9c6c5d054de6c7e526b'; 
  
  Future<TripWeather?> getWeather(String city) async {
    try {
      if (city.isEmpty) return null;
      final url = Uri.parse('https://api.openweathermap.org/data/2.5/weather?q=$city&units=metric&lang=es&appid=$_apiKey');
      
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return TripWeather.fromJson(json.decode(response.body));
      } else if (response.statusCode == 401) {
        throw Exception('API Key inválida o expirada (Código 401). Verifica en weather_service.dart');
      } else if (response.statusCode == 404) {
        throw Exception('Ciudad "$city" no encontrada.');
      }
      throw Exception('Error del servidor: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  Future<TripWeather?> getWeatherByCoords(double lat, double lon) async {
    try {
      final url = Uri.parse('https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&units=metric&lang=es&appid=$_apiKey');
      
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return TripWeather.fromJson(json.decode(response.body));
      } else if (response.statusCode == 401) {
        throw Exception('API Key inválida o expirada (Código 401).');
      }
      throw Exception('Error al obtener clima por GPS: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<String>> searchCities(String query) async {
    try {
      if (query.length < 3) return [];
      if (_apiKey == 'TU_API_KEY_AQUI') return [];
      
      final url = Uri.parse('https://api.openweathermap.org/geo/1.0/direct?q=$query&limit=5&appid=$_apiKey');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((item) {
          final name = item['name'] as String;
          final state = item['state'] as String?;
          final country = item['country'] as String;
          return state != null ? '$name, $state, $country' : '$name, $country';
        }).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}

final weatherServiceProvider = Provider((ref) => WeatherService());

final weatherFutureProvider = FutureProvider.family<TripWeather?, ({String? city, double? lat, double? lon})>((ref, params) async {
  if (params.lat != null && params.lon != null) {
    return ref.watch(weatherServiceProvider).getWeatherByCoords(params.lat!, params.lon!);
  }
  if (params.city != null) {
    return ref.watch(weatherServiceProvider).getWeather(params.city!);
  }
  return null;
});
