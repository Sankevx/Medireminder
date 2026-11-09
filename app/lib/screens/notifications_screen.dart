import 'package:flutter/material.dart';
import '../api.dart';

// ---------- Notificaciones (Fig. 14) ----------
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: FutureBuilder(
          future: Api.get('/notifications'),
          builder: (_, s) {
            if (s.hasError) {
              return Center(
                  child: Text(
                      'No pudimos cargar las notificaciones.\n${s.error}',
                      textAlign: TextAlign.center));
            }
            if (!s.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final l = s.data as List;
            if (l.isEmpty) {
              return const Center(
                  child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.notifications_none_rounded,
                      size: 64, color: Color(0xFF8BA1B2)),
                  SizedBox(height: 12),
                  Text('Estás al día',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  SizedBox(height: 6),
                  Text('No tienes notificaciones pendientes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF657786))),
                ]),
              ));
            }
            return ListView(padding: const EdgeInsets.all(16), children: [
              for (final n in l)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                      child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          leading: CircleAvatar(
                              backgroundColor: n['tipo'] == 'inventario'
                                  ? const Color(0xFFFFF3E0)
                                  : const Color(0xFFFFEBEE),
                              child: Icon(
                                  {
                                        'omitida': Icons.warning_amber_rounded,
                                        'inventario':
                                            Icons.inventory_2_outlined,
                                      }[n['tipo']] ??
                                      Icons.alarm_rounded,
                                  color: n['tipo'] == 'inventario'
                                      ? Colors.orange
                                      : Colors.redAccent)),
                          title: Text(n['texto'],
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          trailing: const Icon(Icons.chevron_right_rounded))),
                ),
            ]);
          }));
}
