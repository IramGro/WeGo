import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/local_trip.dart';
import '../models/itinerary_day.dart';
import '../models/itinerary_item.dart';

class IsarDb {
  static Isar? _isar;

  static Future<Isar> instance() async {
    if (_isar != null) return _isar!;

    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [
        LocalTripSchema,
        ItineraryDaySchema,
        ItineraryItemSchema,
      ],
      directory: dir.path,
    );
    return _isar!;
  }
}
