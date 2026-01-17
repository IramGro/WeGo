import 'package:flutter/material.dart';
import '../itinerary/itinerary_page.dart';
import '../chat/chat_page.dart';
import '../photos/photos_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int idx = 0;

  @override
  Widget build(BuildContext context) {
    final pages = const [
      ItineraryPage(),
      ChatPage(),
      PhotosPage(),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Nuestro Viaje')),
      body: pages[idx],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: idx,
        onTap: (v) => setState(() => idx = v),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.event_note), label: 'Plan'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.photo), label: 'Fotos'),
        ],
      ),
    );
  }
}
