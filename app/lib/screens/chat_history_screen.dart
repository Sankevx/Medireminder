import 'package:flutter/material.dart';
import '../api.dart';
import '../widgets.dart';

// ---------- Chat con el asistente (Fig. 11) ----------
class ChatTab extends StatefulWidget {
  const ChatTab({super.key});
  @override
  State<ChatTab> createState() => _ChatState();
}

class _ChatState extends State<ChatTab> {
  final inp = TextEditingController();
  final msgs = <Map<String, String>>[
    {
      'de': 'ia',
      't':
          '¡Hola! Soy tu asistente virtual de salud. Puedo ayudarte con:\n• Recordatorios y horarios de tus medicamentos\n• Información de los medicamentos registrados\n• Seguimiento de tus dosis y tratamientos'
    }
  ];
  Future<void> send() async {
    final t = inp.text.trim();
    if (t.isEmpty) return;
    setState(() {
      msgs.add({'de': 'yo', 't': t});
      inp.clear();
    });
    try {
      final r = await Api.post('/assistant', {'mensaje': t});
      setState(() => msgs.add({'de': 'ia', 't': r['respuesta']}));
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  @override
  Widget build(BuildContext c) => Column(children: [
        Expanded(
            child: ListView(padding: const EdgeInsets.all(12), children: [
          for (final m in msgs)
            Align(
                alignment: m['de'] == 'yo'
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxWidth: 300),
                    decoration: BoxDecoration(
                        color: m['de'] == 'yo'
                            ? kBlue.withValues(alpha: .12)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(m['t']!)))
        ])),
        Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              Expanded(
                  child: TextField(
                      controller: inp,
                      onSubmitted: (_) => send(),
                      decoration: const InputDecoration(
                          hintText: 'Escribe tu mensaje...',
                          border: OutlineInputBorder()))),
              const SizedBox(width: 8),
              FilledButton(onPressed: send, child: const Text('Enviar'))
            ])),
      ]);
}

// ---------- Adherencia + historial (Fig. 12) ----------
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});
  @override
  State<HistoryTab> createState() => _HistState();
}

class _HistState extends State<HistoryTab> {
  String range = 'week';
  Map stats = {};
  List hist = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final s = await Api.get('/stats?range=$range'),
          h = await Api.get('/history');
      if (mounted)
        setState(() {
          stats = s;
          hist = h;
        });
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  @override
  Widget build(BuildContext c) {
    final dias = ((stats['porDia'] ?? []) as List)
        .reversed
        .take(14)
        .toList()
        .reversed
        .toList();
    final pct = stats['porcentaje'];
    return RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('ADHERENCIA AL TRATAMIENTO',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
              selected: {range},
              onSelectionChanged: (s) {
                range = s.first;
                load();
              },
              segments: const [
                ButtonSegment(value: 'week', label: Text('Semana')),
                ButtonSegment(value: 'month', label: Text('Mes')),
                ButtonSegment(value: 'year', label: Text('Año'))
              ]),
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                  pct == null
                      ? 'Aún no hay información suficiente para mostrar tu cumplimiento.'
                      : 'Cumplimiento: $pct%',
                  style: const TextStyle(fontSize: 18))),
          SizedBox(
              height: 150,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (final d in dias)
                  Expanded(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                        Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            height: (110 *
                                    ((d['tomadas'] as num) /
                                            (d['total'] as num))
                                        .clamp(0.03, 1.0))
                                .toDouble(),
                            decoration: BoxDecoration(
                                color: kBlue,
                                borderRadius: BorderRadius.circular(6))),
                        Text(d['dia'].toString().substring(8),
                            style: const TextStyle(fontSize: 10))
                      ]))
              ])),
          const SizedBox(height: 16),
          const Text('Medicamento',
              style: TextStyle(fontWeight: FontWeight.bold)),
          for (final m in (stats['porMed'] ?? []) as List)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  SizedBox(
                      width: 100,
                      child:
                          Text(m['nombre'], overflow: TextOverflow.ellipsis)),
                  Expanded(
                      child: LinearProgressIndicator(
                          value: m['tomadas'] / m['total'],
                          minHeight: 10,
                          borderRadius: BorderRadius.circular(5)))
                ])),
          const Divider(height: 32),
          const Text('Historial de dosis',
              style: TextStyle(fontWeight: FontWeight.bold)),
          if (hist.isEmpty)
            const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Aún no hay registros.')),
          for (final h in hist)
            ListTile(
                dense: true,
                leading: Icon(stIcon(h['resultado'])),
                title: Text('${h['nombre']} ${h['dosis']}'),
                subtitle: Text('${h['fecha_hora_real']} · ${h['resultado']}')),
        ]));
  }
}
