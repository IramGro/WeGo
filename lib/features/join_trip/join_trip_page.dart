import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

import '../../data/repositories/trip_repository.dart';

class JoinTripPage extends StatefulWidget {
  const JoinTripPage({super.key});

  @override
  State<JoinTripPage> createState() => _JoinTripPageState();
}

class _JoinTripPageState extends State<JoinTripPage> {
  final _repo = TripRepository();

  final _createName = TextEditingController();
  final _joinCode = TextEditingController();

  bool _loading = false;
  String? _createdCode;
  String? _createdTripId;
  String? _error;

  @override
  void dispose() {
    _createName.dispose();
    _joinCode.dispose();
    super.dispose();
  }

  Future<void> _createTrip() async {
    final name = _createName.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _createdCode = null;
      _createdTripId = null;
    });

    try {
      final result = await _repo.createTrip(name: name);
      setState(() {
        _createdCode = result.code;
        _createdTripId = result.tripId;
      });

      // Copiar automáticamente el código
      await Clipboard.setData(ClipboardData(text: result.code));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Código copiado: ')),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _joinTrip() async {
    final code = _joinCode.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _repo.joinTripByCode(code: code);
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trip App')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Crear viaje',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _createName,
            decoration: const InputDecoration(
              labelText: 'Nombre del viaje',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _loading ? null : _createTrip,
            child: _loading ? const Text('Creando...') : const Text('Crear'),
          ),

          if (_createdCode != null) ...[
            const SizedBox(height: 16),
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
                  _createdCode!,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _createdCode!));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Código copiado')),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copiar código'),
            ),
            if (_createdTripId != null) ...[
              const SizedBox(height: 6),
              Text(
                'tripId (debug): ',
                style: const TextStyle(fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loading ? null : () => context.go('/home'),
              child: const Text('Entrar al viaje'),
            ),
          ],

          const Divider(height: 32),

          const Text(
            'Unirme a un viaje',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _joinCode,
            decoration: const InputDecoration(
              labelText: 'Código (6 letras/números)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _loading ? null : _joinTrip,
            child: const Text('Unirme'),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],

          const Divider(height: 32),
          
          const Text(
            'Mis Viajes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _repo.getUserTrips(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Text('Error al cargar viajes');
              }
              final trips = snapshot.data ?? [];
              if (trips.isEmpty) {
                return const Text('No tienes viajes guardados.', style: TextStyle(color: Colors.grey));
              }

              return Column(
                children: trips.map((t) {
                   return Card(
                     child: ListTile(
                       title: Text(t['name']),
                       subtitle: Text('Código: ${t['code']}'),
                       trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                       onTap: () async {
                         // Set as current trip locally
                         await _repo.selectTrip(
                           tripId: t['id'], 
                           name: t['name'], 
                           code: t['code']
                         );
                         if (!mounted) return;
                         context.go('/home');
                       },
                     ),
                   );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
