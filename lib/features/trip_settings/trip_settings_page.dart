import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme_provider.dart';
import '../../core/providers.dart';
import '../../data/local/local_trip_store.dart';
import '../../data/repositories/trip_repository.dart';
import '../auth/auth_controller.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/weather_service.dart';

class TripSettingsPage extends ConsumerStatefulWidget {
  const TripSettingsPage({super.key});

  @override
  ConsumerState<TripSettingsPage> createState() => _TripSettingsPageState();
}

class _TripSettingsPageState extends ConsumerState<TripSettingsPage> {
  final _store = LocalTripStore();

  bool _loading = true;
  String? _name;
  String? _code;
  String? _tripId;

  DateTime? _startDate;
  DateTime? _endDate;

  final _fmt = DateFormat('EEE, d MMM yyyy', 'es_MX');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final t = await _store.getCurrentTrip();
    setState(() {
      _name = t?.name;
      _code = t?.code;
      _tripId = t?.tripId;
      _startDate = t?.startDate;
      _endDate = t?.endDate;
      _destination = t?.destination;
      _useGeolocation = t?.useGeolocation ?? false;
      _loading = false;
    });
  }

  String? _destination;
  bool _useGeolocation = false;

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final initial = _startDate ?? now;
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      initialDate: initial,
    );
    if (picked == null) return;
    setState(() => _startDate = DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _pickEnd() async {
    final now = DateTime.now();
    final initial = _endDate ?? (_startDate ?? now);
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      initialDate: initial,
    );
    if (picked == null) return;
    setState(() => _endDate = DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _saveDates() async {
    if (_startDate == null || _endDate == null || _tripId == null) return;

    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La fecha final no puede ser antes que la inicial.')),
      );
      return;
    }

    try {
      await TripRepository().updateTripDates(
        tripId: _tripId!,
        startDate: _startDate!,
        endDate: _endDate!,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fechas guardadas')),
      );

      // Return to home and switch to Plan tab (index 0)
      ref.read(tabIndexProvider.notifier).state = 0;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    }
  }

  Future<void> _editAlias() async {
     final user = ref.read(authControllerProvider).currentUser;
     if (user == null) return;

     final controller = TextEditingController(text: user.displayName);
     final newName = await showDialog<String>(
       context: context,
       builder: (context) => AlertDialog(
         title: const Text('Editar Alias'),
         content: TextField(
           controller: controller,
           decoration: const InputDecoration(labelText: 'Nombre para el chat'),
         ),
         actions: [
           TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
           ElevatedButton(
             onPressed: () => Navigator.pop(context, controller.text.trim()),
             child: const Text('Guardar'),
           ),
         ],
       ),
     );

     if (newName != null && newName.isNotEmpty) {
       await user.updateDisplayName(newName);
       if (!mounted) return;
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alias actualizado')));
       // Force rebuild to show new name if displayed ?? but displayName is on auth user
       setState(() {}); 
     }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración del viaje')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_code == null)
                ? const Center(child: Text('No hay viaje guardado todavía.'))
                : ListView(
                    children: [
                      Text(
                        _name ?? 'Viaje',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 16),
                      
                      const Text(
                        'Perfil',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(user?.displayName ?? 'Usuario'),
                        subtitle: const Text('Toca para cambiar tu alias'),
                        trailing: const Icon(Icons.edit, size: 16),
                        onTap: _editAlias,
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'Ubicación del Clima',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      ListTile(
                        leading: const Icon(Icons.map_outlined),
                        title: const Text('Destino'),
                        subtitle: Text(_destination ?? 'No configurado (usa nombre del viaje)'),
                        trailing: const Icon(Icons.edit, size: 16),
                        onTap: _editDestination,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Usar mi ubicación actual'),
                        subtitle: const Text('Actualiza el clima por GPS'),
                        secondary: const Icon(Icons.my_location),
                        value: _useGeolocation,
                        onChanged: (val) async {
                          if (_tripId == null) return;
                          setState(() => _useGeolocation = val);
                          await TripRepository().updateTripLocation(
                            tripId: _tripId!,
                            destination: _destination,
                            useGeolocation: val,
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        'Código del viaje',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: SelectableText(
                            _code!,
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                           await Clipboard.setData(ClipboardData(text: _code!));
                           if (!mounted) return;
                           ScaffoldMessenger.of(context).showSnackBar(
                             const SnackBar(content: Text('Código copiado')),
                           );
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copiar código'),
                      ),
                      
                      const SizedBox(height: 24),
                      const Text(
                        'Fechas del viaje',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),

                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Fecha inicio'),
                        subtitle: Text(_startDate == null ? 'Sin definir' : _fmt.format(_startDate!)),
                        trailing: const Icon(Icons.date_range),
                        onTap: _pickStart,
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Fecha fin'),
                        subtitle: Text(_endDate == null ? 'Sin definir' : _fmt.format(_endDate!)),
                        trailing: const Icon(Icons.date_range),
                        onTap: _pickEnd,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _saveDates,
                        child: const Text('Guardar fechas'),
                      ),
                      const SizedBox(height: 16),
                      
                      const Divider(height: 32),
                      const Text(
                        'Apariencia',
                         style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      Consumer(
                        builder: (context, ref, child) {
                          final mode = ref.watch(themeModeProvider);
                          return Column(
                            children: [
                              RadioListTile<ThemeMode>(
                                title: const Text('Sistema'),
                                value: ThemeMode.system,
                                groupValue: mode,
                                onChanged: (val) => ref.read(themeModeProvider.notifier).state = val!,
                              ),
                              RadioListTile<ThemeMode>(
                                title: const Text('Claro'),
                                value: ThemeMode.light,
                                groupValue: mode,
                                onChanged: (val) => ref.read(themeModeProvider.notifier).state = val!,
                              ),
                              RadioListTile<ThemeMode>(
                                title: const Text('Oscuro'),
                                value: ThemeMode.dark,
                                groupValue: mode,
                                onChanged: (val) => ref.read(themeModeProvider.notifier).state = val!,
                              ),
                            ],
                          );
                        },
                      ),

                      const Divider(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await ref.read(authControllerProvider).signOut();
                            // Router redirect logic handles the rest
                          },
                          icon: const Icon(Icons.logout, color: Colors.red),
                          label: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
      ),
    );
  }

  Future<void> _editDestination() async {
    if (_tripId == null) return;
    
    String? selectedTemp = _destination;
    final newDest = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Destino del Viaje'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Escribe para ver sugerencias:', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _destination ?? ''),
                optionsBuilder: (TextEditingValue textEditingValue) async {
                  if (textEditingValue.text.length < 3) return const Iterable<String>.empty();
                  return await ref.read(weatherServiceProvider).searchCities(textEditingValue.text);
                },
                onSelected: (String selection) {
                  selectedTemp = selection;
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Ciudad',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.search),
                    ),
                    onChanged: (val) => selectedTemp = val,
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, selectedTemp),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (newDest != null) {
      setState(() => _destination = newDest);
      await TripRepository().updateTripLocation(
        tripId: _tripId!,
        destination: newDest,
        useGeolocation: _useGeolocation,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Destino actualizado')));
      }
    }
  }
}
