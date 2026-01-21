import 'package:isar/isar.dart';
export 'package:isar/isar.dart'; // Export Isar types for usage in stores
import 'package:path_provider/path_provider.dart';

// Must import native models to see the Schemas
import '../models/local_trip_native.dart';
import '../models/itinerary_day_native.dart';
import '../models/itinerary_item_native.dart';

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
