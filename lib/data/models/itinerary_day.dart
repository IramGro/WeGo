import 'package:isar/isar.dart';

part 'itinerary_day.g.dart';

@collection
class ItineraryDay {
  Id id = Isar.autoIncrement;

  @Index()
  late String tripId;

  @Index()
  late DateTime date; // día (fecha)

  late int dayNumber; // Día 1, 2, 3...
}
