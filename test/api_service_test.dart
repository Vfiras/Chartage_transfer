import 'package:flutter_test/flutter_test.dart';
import 'package:luxury_airport_transfer/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fetchReviews reads bundled review data', () async {
    const service = ApiService();

    final reviews = await service.fetchReviews();

    expect(reviews.length, greaterThan(0));
    expect(reviews.first.author, isNotEmpty);
  });
}
