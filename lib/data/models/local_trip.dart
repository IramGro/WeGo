import 'package:isar/isar.dart';

part 'local_trip.g.dart';

@collection
class LocalTrip {
  Id id = Isar.autoIncrement;

  late String tripId;
  late String name;
  late String code;

  DateTime? joinedAt;

  // Fechas del viaje (opción A)
  DateTime? startDate;
  DateTime? endDate;

  String? destination;
  bool useGeolocation = false;
}
