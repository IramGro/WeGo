class LocalTrip {
  int id = 0;

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
