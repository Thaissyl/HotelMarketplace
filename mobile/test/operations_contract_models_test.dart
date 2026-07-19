import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_marketplace_mobile/features/operations/domain/operations_models.dart';

void main() {
  test('serializes owner hotel registration contract', () {
    const request = RegisterHotelRequest(
      name: ' Riverside Hotel ',
      city: ' Ho Chi Minh City ',
      addressLine: ' 10 River Street ',
      contactEmail: ' owner@example.com ',
      contactPhone: '0901234567',
      description: ' Guest-facing description ',
    );

    expect(request.toJson(), {
      'name': 'Riverside Hotel',
      'city': 'Ho Chi Minh City',
      'addressLine': '10 River Street',
      'contactEmail': 'owner@example.com',
      'contactPhone': '0901234567',
      'description': 'Guest-facing description',
    });
  });

  test('parses and serializes complete hotel content contract', () {
    final content = HotelContent.fromJson({
      'images': [
        {'imageUrl': 'https://example.com/hotel.jpg', 'displayOrder': 0},
      ],
      'amenities': [
        {'code': 'WIFI', 'name': 'Free Wi-Fi', 'type': 'Connectivity'},
      ],
      'cancellationPolicy': {
        'name': 'Flexible',
        'freeCancellationHours': 24,
        'refundPercentage': 100,
        'description': 'Full refund before the deadline.',
      },
    });

    expect(content.images.single.displayOrder, 0);
    expect(content.amenities.single.code, 'WIFI');
    expect(content.cancellationPolicy?.refundPercentage, 100);

    final request = UpdateHotelContentRequest(
      images: content.images,
      amenities: content.amenities,
      cancellationPolicy: content.cancellationPolicy,
    );
    expect(
      (request.toJson()['cancellationPolicy']
          as Map<String, dynamic>)['refundPercentage'],
      100,
    );
  });
}
