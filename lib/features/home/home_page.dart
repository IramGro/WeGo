import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../itinerary/itinerary_page.dart';
import '../chat/chat_page.dart';
import '../photos/photos_page.dart';
import '../tickets/tickets_page.dart';
import '../../core/providers.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  Widget build(BuildContext context) {
    final idx = ref.watch(tabIndexProvider);
    
    final pages = const [
      ItineraryPage(),
      ChatPage(),
      PhotosPage(),
      TicketsPage(),
    ];

    final tripAsync = ref.watch(currentTripStreamProvider);
    final tripName = tripAsync.maybeWhen(
      data: (t) => t?.name ?? 'Mi Viaje',
      orElse: () => 'Mi Viaje',
    );

    String title;
    switch (idx) {
      case 0: title = tripName; break;
      case 1: title = 'Chat de $tripName'; break;
      case 2: title = 'Galería de $tripName'; break;
      case 3: title = 'Tickets de $tripName'; break;
      default: title = tripName;
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (idx == 0) // Only on Plan page
               const Text('Tu aventura comienza aquí', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: Colors.grey)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              child: IconButton(
                onPressed: () => context.push('/settings'),
                icon: Icon(Icons.person_outline, color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ),
        ],
      ),
      body: pages[idx],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          elevation: 0,
          currentIndex: idx,
          onTap: (v) => ref.read(tabIndexProvider.notifier).state = v,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore),
              label: 'Plan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Chat',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.photo_library_outlined),
              activeIcon: Icon(Icons.photo_library),
              label: 'Fotos',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_awesome_motion_outlined),
              activeIcon: Icon(Icons.auto_awesome_motion),
              label: 'Tickets',
            ),
          ],
        ),
      ),
    );
  }
}
