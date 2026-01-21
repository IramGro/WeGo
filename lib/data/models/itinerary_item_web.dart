class ItineraryItem {
  int id = 0;

  late String tripId;

  late DateTime dayDate; // misma fecha del día

  String? timeHHmm; // '09:30' (opcional)
  late String title;
  String? notes;
  String? locationUrl;

  DateTime? createdAt;
  DateTime? updatedAt;
  
  String? firestoreId;
}
