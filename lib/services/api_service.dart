import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../models/article.dart';
import '../models/fleet_item.dart';
import '../models/location_tile.dart';
import '../models/review.dart';
import '../models/sponsor.dart';

class ApiService {
  final String? baseUrl;
  final bool useNetwork;

  const ApiService({
    this.baseUrl,
    this.useNetwork = false,
  });

  Future<List<Review>> fetchReviews() async {
    final items = await _loadList('/api/reviews', 'assets/data/reviews.json');
    return items.map(Review.fromJson).toList();
  }

  Future<List<Sponsor>> fetchSponsors() async {
    final items = await _loadList('/api/sponsors', 'assets/data/sponsors.json');
    return items.map(Sponsor.fromJson).toList();
  }

  Future<List<FleetItem>> fetchFleet() async {
    final items = await _loadList('/api/fleet', 'assets/data/fleet.json');
    return items.map(FleetItem.fromJson).toList();
  }

  Future<List<LocationTile>> fetchLocations() async {
    final items =
        await _loadList('/api/locations', 'assets/data/locations.json');
    return items.map(LocationTile.fromJson).toList();
  }

  Future<List<Article>> fetchArticles() async {
    final items = await _loadList('/api/articles', 'assets/data/articles.json');
    return items.map(Article.fromJson).toList();
  }

  Future<List<Map<String, dynamic>>> _loadList(
    String endpoint,
    String assetPath,
  ) async {
    if (useNetwork && baseUrl != null) {
      try {
        // Live wiring point:
        // GET $baseUrl/api/reviews
        // GET $baseUrl/api/sponsors
        // GET $baseUrl/api/fleet
        // GET $baseUrl/api/locations
        // GET $baseUrl/api/articles
        final uri = Uri.parse('$baseUrl$endpoint');
        final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
        final request = await client.getUrl(uri);
        final response = await request.close();
        final body = await response.transform(utf8.decoder).join();
        client.close();

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(body) as List<dynamic>;
          return decoded.cast<Map<String, dynamic>>();
        }
      } catch (_) {
        // Fall through to bundled sample data when the API is not reachable.
      }
    }

    final body = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(body) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }
}
