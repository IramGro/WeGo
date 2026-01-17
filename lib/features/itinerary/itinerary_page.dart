import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/local/local_trip_store.dart';
import '../../data/repositories/itinerary_repository.dart';
import '../../data/models/itinerary_item.dart';
import '../../core/providers.dart';
import '../../core/services/weather_service.dart';
import '../../core/services/location_service.dart';

class ItineraryPage extends ConsumerStatefulWidget {
  const ItineraryPage({super.key});

  @override
  ConsumerState<ItineraryPage> createState() => _ItineraryPageState();
}

class _ItineraryPageState extends ConsumerState<ItineraryPage> {
  final _repo = ItineraryRepository();
  final _fmt = DateFormat('EEE, d MMM yyyy', 'es_MX');

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(currentTripStreamProvider);

    return tripAsync.when(
      data: (trip) {
        if (trip == null) {
          return const Center(child: Text('No hay viaje cargado.'));
        }

        final tripId = trip.tripId;
        final start = trip.startDate;
        final end = trip.endDate;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: _WeatherHeader(
                cityName: trip.destination ?? trip.name,
                useGeolocation: trip.useGeolocation,
              ),
            ),
            Expanded(
              child: Builder(
                builder: (context) {
                  if (start == null || end == null) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Configura las fechas del viaje en Configuración (⚙️) para ver el itinerario.'),
                      ),
                    );
                  }

                  return FutureBuilder(
                    future: _repo.ensureDays(tripId: tripId, startDate: start, endDate: end),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                         return const Center(child: CircularProgressIndicator());
                      }

                      final dayList = <DateTime>[];
                      final startDateClean = DateTime(start.year, start.month, start.day);
                      final endDateClean = DateTime(end.year, end.month, end.day);
                      
                      for (var d = startDateClean; !d.isAfter(endDateClean); d = d.add(const Duration(days: 1))) {
                        dayList.add(d);
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: dayList.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final dayDate = dayList[i];
                          return _DayCard(tripId: tripId, dayDate: dayDate, repo: _repo, fmt: _fmt);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text('Error: $err')),
    );
  }
}

class _WeatherHeader extends ConsumerWidget {
  final String cityName;
  final bool useGeolocation;

  const _WeatherHeader({required this.cityName, required this.useGeolocation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _WeatherLoader(cityName: cityName, useGeolocation: useGeolocation);
  }
}

class _WeatherLoader extends StatefulWidget {
  final String cityName;
  final bool useGeolocation;

  const _WeatherLoader({required this.cityName, required this.useGeolocation});

  @override
  State<_WeatherLoader> createState() => _WeatherLoaderState();
}

class _WeatherLoaderState extends State<_WeatherLoader> {
  late Future<({String? city, double? lat, double? lon})> _paramsFuture;

  @override
  void initState() {
    super.initState();
    _paramsFuture = _getParams();
  }

  @override
  void didUpdateWidget(_WeatherLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cityName != widget.cityName || oldWidget.useGeolocation != widget.useGeolocation) {
      setState(() {
        _paramsFuture = _getParams();
      });
    }
  }

  Future<({String? city, double? lat, double? lon})> _getParams() async {
    if (widget.useGeolocation) {
      final pos = await LocationService().getCurrentPosition();
      if (pos != null) {
        final detectedCity = await LocationService().getCityFromPosition(pos.latitude, pos.longitude);
        return (city: detectedCity, lat: pos.latitude, lon: pos.longitude);
      } else {
        // Si falló el GPS pero se pidió geolocalización
        throw Exception('No se pudo obtener la ubicación GPS. Verifica tu señal o configuración.');
      }
    }
    return (city: widget.cityName, lat: null as double?, lon: null as double?);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({String? city, double? lat, double? lon})>(
      future: _paramsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                   const Icon(Icons.location_off, color: Colors.orange, size: 24),
                   const SizedBox(height: 8),
                   Text(
                     '${snapshot.error}'.replaceAll('Exception: ', ''),
                     textAlign: TextAlign.center,
                     style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                   ),
                   TextButton(
                     onPressed: () => setState(() => _paramsFuture = _getParams()),
                     child: const Text('Reintentar', style: TextStyle(fontSize: 12)),
                   )
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
           return const Card(child: SizedBox(height: 80, child: Center(child: CircularProgressIndicator(strokeWidth: 2))));
        }
        
        final params = snapshot.data ?? (city: widget.cityName, lat: null, lon: null);
        
        return Consumer(
          builder: (context, ref, _) {
            final weatherAsync = ref.watch(weatherFutureProvider(params));

            return weatherAsync.when(
              data: (weather) {
                if (weather == null) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: Text(
                          'Sin datos de clima. Revisa el destino en Ajustes.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ),
                  );
                }
                
                return Card(
                  elevation: 0,
                  color: Colors.blue[50],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Image.network(
                          'https://openweathermap.org/img/wn/${weather.icon}@2x.png',
                          width: 50,
                          height: 50,
                          errorBuilder: (_, __, ___) => const Icon(Icons.cloud, color: Colors.blue),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.useGeolocation ? 'Ubicación actual (${weather.cityName})' : 'Clima en ${weather.cityName}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey),
                              ),
                              Text(
                                weather.description.toUpperCase(),
                                style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${weather.temp.round()}°C',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const Card(child: SizedBox(height: 80, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))),
              error: (err, _) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('Error: $err', style: const TextStyle(fontSize: 10)))),
            );
          },
        );
      },
    );
  }
}

class _DayCard extends StatefulWidget {
  final String tripId;
  final DateTime dayDate;
  final ItineraryRepository repo;
  final DateFormat fmt;

  const _DayCard({
    required this.tripId,
    required this.dayDate,
    required this.repo,
    required this.fmt,
  });

  @override
  State<_DayCard> createState() => _DayCardState();
}

class _DayCardState extends State<_DayCard> {
  Future<void> _addItem() async {
    final titleCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    TimeOfDay? selectedTime;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Agregar actividad'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Título *'),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Hora'),
                      subtitle: Text(selectedTime == null ? 'Sin hora' : selectedTime!.format(context)),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedTime = picked);
                        }
                      },
                    ),
                    TextField(
                      controller: locationCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Link de ubicación (Maps/Waze)',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(labelText: 'Notas (opcional)'),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return;

    final title = titleCtrl.text.trim();
    if (title.isEmpty) return;

    String? timeStr;
    if (selectedTime != null) {
      final hh = selectedTime!.hour.toString().padLeft(2, '0');
      final mm = selectedTime!.minute.toString().padLeft(2, '0');
      timeStr = '$hh:$mm';
    }

    await widget.repo.addItem(
      tripId: widget.tripId,
      dayDate: widget.dayDate,
      title: title,
      timeHHmm: timeStr,
      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      locationUrl: locationCtrl.text.trim().isEmpty ? null : locationCtrl.text.trim(),
    );

    setState(() {});
  }

  Future<void> _deleteItem(ItineraryItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar actividad'),
        content: Text('¿Estás seguro de que quieres eliminar "${item.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.repo.deleteItem(item.id);
      setState(() {});
    }
  }

  Future<void> _openMap(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<List<ItineraryItem>>(
          future: widget.repo.listItems(tripId: widget.tripId, dayDate: widget.dayDate),
          builder: (context, snap) {
            final items = snap.data ?? const <ItineraryItem>[];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.fmt.format(widget.dayDate).toUpperCase(),
                        style: TextStyle(
                          fontSize: 12, 
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add_circle_outline, size: 24),
                      color: Theme.of(context).colorScheme.primary,
                      tooltip: 'Agregar',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Sin actividades todavía.',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13, fontStyle: FontStyle.italic),
                      ),
                    ),
                  )
                else
                  ...items.map((it) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: 50,
                              child: Column(
                                children: [
                                  Text(
                                    it.timeHHmm ?? '--:--',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: it.timeHHmm != null ? Theme.of(context).colorScheme.primary : Colors.grey,
                                      fontWeight: it.timeHHmm != null ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      width: 2,
                                      margin: const EdgeInsets.symmetric(vertical: 4),
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white.withOpacity(0.05)
                                      : Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.05)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            it.title,
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                          ),
                                          if (it.notes != null)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Text(
                                                it.notes!,
                                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (it.locationUrl != null && it.locationUrl!.isNotEmpty) ...[
                                      IconButton(
                                        onPressed: () => _openMap(it.locationUrl!),
                                        icon: const Icon(Icons.directions_outlined, size: 20, color: Colors.blue),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        tooltip: 'Cómo llegar',
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    IconButton(
                                      onPressed: () => _deleteItem(it),
                                      icon: Icon(Icons.delete_outline, size: 20, color: Colors.redAccent.withOpacity(0.6)),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: 'Eliminar',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}
