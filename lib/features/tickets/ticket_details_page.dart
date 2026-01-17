import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'ticket_model.dart';

class TicketDetailsPage extends StatelessWidget {
  final Ticket ticket;

  const TicketDetailsPage({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    final isPdf = ticket.fileType == 'pdf';
    final dateStr = DateFormat('EEE, d MMM yyyy HH:mm', 'es_MX').format(ticket.uploadedAt);

    return Scaffold(
      appBar: AppBar(
        title: Text(ticket.title),
      ),
      body: Column(
        children: [
          Expanded(
            child: isPdf
                ? SfPdfViewer.network(ticket.url)
                : InteractiveViewer(
                    child: Image.network(
                      ticket.url,
                      loadingBuilder: (_, child, prog) {
                        if (prog == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (_, __, ___) => const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: Colors.red),
                            SizedBox(height: 8),
                            Text('No se pudo cargar la imagen'),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticket.title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        'Subido el $dateStr',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const Spacer(),
                      Chip(
                        label: Text(ticket.fileType.toUpperCase()),
                        backgroundColor: Colors.grey.withOpacity(0.2),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
