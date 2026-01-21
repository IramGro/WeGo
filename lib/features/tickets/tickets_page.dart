import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'tickets_controller.dart';
import 'ticket_model.dart';
import 'ticket_details_page.dart';
import 'package:intl/intl.dart';

class TicketsPage extends ConsumerStatefulWidget {
  const TicketsPage({super.key});

  @override
  ConsumerState<TicketsPage> createState() => _TicketsPageState();
}

class _TicketsPageState extends ConsumerState<TicketsPage> {
  bool _uploading = false;

  Future<void> _addTicket() async {
    final titleCtrl = TextEditingController();

    // 1. Ask for Title
    final next = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nuevo Ticket'),
        content: TextField(
          controller: titleCtrl,
          decoration: const InputDecoration(
            labelText: 'Título del documento',
            hintText: 'Ej. Vuelos, Reservación Hotel...',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Siguiente'),
          ),
        ],
      ),
    );

    if (next != true || titleCtrl.text.trim().isEmpty) return;
    
    // 2. Pick File
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png'],
    );

    if (result != null) {
      setState(() => _uploading = true);
      try {
        await ref.read(ticketsControllerProvider.notifier).uploadTicket(
          file: result.files.single, 
          title: titleCtrl.text.trim()
        );
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Ticket subido correctamente'))
           );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Error al subir: $e'), backgroundColor: Colors.red)
           );
        }
      } finally {
        if (mounted) setState(() => _uploading = false);
      }
    }
  }

  Future<void> _openTicket(Ticket ticket) async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TicketDetailsPage(ticket: ticket),
      ),
    );
  }
  
  Future<void> _deleteTicket(Ticket ticket) async {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Eliminar Ticket'),
          content: Text('¿Seguro que quieres eliminar "${ticket.title}"?'),
           actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
             child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
        ),
      );
      
      if (confirm == true) {
        try {
          await ref.read(ticketsControllerProvider.notifier).deleteTicket(ticket);
        } catch (e) {
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text('Error al eliminar: $e'))
             );
           }
        }
      }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ticketsControllerProvider);

    if (_uploading) {
      return const Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Subiendo archivo...'),
        ],
      ));
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _addTicket,
        child: const Icon(Icons.add),
        tooltip: 'Agregar Ticket',
      ),
      body: state.when(
        data: (tickets) {
          if (tickets.isEmpty) {
            return const Center(
              child: Text(
                'No hay tickets aún.\n¡Sube tus reservaciones aquí!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: tickets.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final t = tickets[index];
              final dateStr = DateFormat('d MMM yyyy', 'es_MX').format(t.uploadedAt);
              
              IconData icon;
              Color color;
              switch (t.fileType) {
                case 'pdf': icon = Icons.picture_as_pdf_outlined; color = Colors.redAccent; break;
                case 'doc': 
                case 'docx': icon = Icons.description_outlined; color = Colors.blueAccent; break;
                case 'jpg':
                case 'png': icon = Icons.image_outlined; color = Colors.purpleAccent; break;
                default: icon = Icons.insert_drive_file_outlined; color = Colors.grey;
              }

              final isImage = ['jpg', 'png', 'jpeg'].contains(t.fileType);

              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isImage ? null : color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: isImage
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              t.url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(Icons.broken_image_outlined, color: Colors.grey[400]),
                            ),
                          )
                        : Icon(icon, color: color, size: 28),
                  ),
                  title: Text(
                    t.title, 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          dateStr, 
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            t.fileType.toUpperCase(),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.redAccent.withOpacity(0.5)),
                    onPressed: () => _deleteTicket(t),
                  ),
                  onTap: () => _openTicket(t),
                ),
              );
            },
          );
        },
        error: (err, st) => Center(child: Text('Error: $err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
