// Stub for Web - No Isar dependency
import '../models/local_trip.dart';
import '../models/itinerary_day.dart';
import '../models/itinerary_item.dart';

typedef Id = int;

class IsarDb {
  static Future<Isar> instance() async {
    throw UnsupportedError('Isar is not supported on Web. Use Firestore.');
  }
}

// Stub Isar class to satisfy return type
class Isar {
  late _Collection<LocalTrip> localTrips;
  late _Collection<ItineraryDay> itineraryDays;
  late _Collection<ItineraryItem> itineraryItems;

  Future<T> writeTxn<T>(Future<T> Function() callback) async {
    throw UnsupportedError('Isar not supported on Web');
  }
}

// Stub helper classes with Generics
class _Collection<T> {
  Future<void> put(T object) async {}
  Future<void> delete(int id) async {}
  Future<void> clear() async {}
  _Query<T> where() => _Query<T>();
  _Query<T> filter() => _Query<T>();
}

class _Query<T> {
  Future<List<T>> findAll() async => [];
  Future<T?> findFirst() async => null;
  Stream<List<T>> watch({bool fireImmediately = false}) => Stream.empty();
  
  // Fluent interface stubs - return typed Query
  _Query<T> filter() => this; // Added missing filter() method
  _Query<T> tripIdEqualTo(String id) => this;
  _Query<T> dateEqualTo(DateTime d) => this;
  _Query<T> dayDateEqualTo(DateTime d) => this;
  _Query<T> sortByDate() => this;
  _Query<T> and() => this;
}
