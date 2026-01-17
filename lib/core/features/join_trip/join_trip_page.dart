import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class JoinTripPage extends StatelessWidget {
  const JoinTripPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip App'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () => context.go('/home'),
          child: const Text('Entrar (placeholder)'),
        ),
      ),
    );
  }
}