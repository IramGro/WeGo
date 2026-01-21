import 'package:isar/isar.dart';

part 'itinerary_item_native.g.dart';

@collection
class ItineraryItem {
  Id id = Isar.autoIncrement;

  @Index()
  late String tripId;

  @Index()
  late DateTime dayDate; // misma fecha del día

  String? timeHHmm; // '09:30' (opcional)
  late String title;
  String? notes;
  String? locationUrl;

  DateTime? createdAt;
  DateTime? updatedAt;
}
