import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../api.dart';
import '../dose_reminder_service.dart';
import '../widgets.dart';
import 'chat_history_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

// ---------- Shell con barra inferior (Cal / Med / Chat / Hist) ----------
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int i = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _syncDoseReminders(requestPermission: true),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _syncDoseReminders();
  }

  Future<void> _syncDoseReminders({bool requestPermission = false}) async {
    try {
      if (requestPermission) {
        final exactTimings =
            await DoseReminderService.instance.requestPermissions(context);
        if (!exactTimings && mounted) {
          snack(
            context,
            'Los avisos están activados, pero Android podría mostrarlos con retraso.',
          );
        }
      }
      await DoseReminderService.instance.synchronizePendingDoses();
    } catch (error) {
      if (mounted) snack(context, error);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(
          leading: IconButton(
              tooltip: 'Abrir perfil y accesibilidad',
              onPressed: () => Navigator.push(
                  c, MaterialPageRoute(builder: (_) => const ProfileScreen())),
              icon: const CircleAvatar(
                  backgroundColor: Color(0xFFE3F2FD),
                  child: Icon(Icons.person_outline, color: kBlue))),
          title: const Text('MediReminder',
              style: TextStyle(
                  color: Color(0xFF183B56), fontWeight: FontWeight.w800)),
          actions: [
            IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => Navigator.push(
                    c,
                    MaterialPageRoute(
                        builder: (_) => const NotificationsScreen())))
          ]),
      body: IndexedStack(index: i, children: [
        const CalendarTab(),
        const MedsTab(),
        const ChatTab(),
        const HistoryTab()
      ]),
      bottomNavigationBar: NavigationBar(
          selectedIndex: i,
          onDestinationSelected: (v) => setState(() => i = v),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month),
                label: 'Calendario'),
            NavigationDestination(
                icon: Icon(Icons.medication_outlined),
                selectedIcon: Icon(Icons.medication),
                label: 'Medicinas'),
            NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline),
                selectedIcon: Icon(Icons.chat_bubble),
                label: 'Asistente'),
            NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: 'Historial'),
          ]));
}

IconData stIcon(String s) =>
    {
      'tomada': Icons.check_circle,
      'omitida': Icons.cancel,
      'pospuesta': Icons.schedule
    }[s] ??
    Icons.radio_button_unchecked;

// ---------- Inicio: buscador + calendario + dosis del día (Fig. 9) ----------
class CalendarTab extends StatefulWidget {
  const CalendarTab({super.key});
  @override
  State<CalendarTab> createState() => _CalState();
}

class _CalState extends State<CalendarTab> {
  DateTime sel = DateTime.now();
  List doses = [];
  String q = '';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await Api.get('/doses?date=${fmt(sel)}');
      if (mounted) setState(() => doses = r);
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  @override
  Widget build(BuildContext c) {
    final shown = doses
        .where((d) =>
            d['nombre'].toString().toLowerCase().contains(q.toLowerCase()))
        .toList();
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            TextField(
                onChanged: (v) => setState(() => q = v),
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar medicamento',
                    suffixIcon: Icon(Icons.tune_outlined))),
            const SizedBox(height: 12),
            Card(
              child: TableCalendar(
                  firstDay: DateTime(2020),
                  lastDay: DateTime(2100),
                  focusedDay: sel,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  headerStyle: const HeaderStyle(
                      titleCentered: true,
                      formatButtonVisible: false,
                      leftChevronIcon: Icon(Icons.chevron_left_rounded),
                      rightChevronIcon: Icon(Icons.chevron_right_rounded)),
                  calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                          color: kBlue.withValues(alpha: .15),
                          shape: BoxShape.circle),
                      todayTextStyle: const TextStyle(
                          color: kBlue, fontWeight: FontWeight.w700),
                      selectedDecoration: const BoxDecoration(
                          color: kBlue, shape: BoxShape.circle)),
                  selectedDayPredicate: (d) => isSameDay(d, sel),
                  onDaySelected: (d, _) {
                    setState(() => sel = d);
                    load();
                  }),
            ),
            const Padding(
                padding: EdgeInsets.fromLTRB(4, 20, 4, 10),
                child: Text('Medicamentos del día',
                    style:
                        TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
            if (shown.isEmpty)
              Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE8EFF4))),
                  child: const Column(children: [
                    Icon(Icons.event_available_outlined,
                        size: 44, color: Color(0xFF8BA1B2)),
                    SizedBox(height: 10),
                    Text('Sin medicamentos para este día',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    Text('Puedes seleccionar otra fecha en el calendario.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF657786))),
                  ])),
            for (final d in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                    child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        leading: CircleAvatar(
                            backgroundColor: const Color(0xFFE3F2FD),
                            child: Icon(stIcon(d['estado']), color: kBlue)),
                        title: Text('${d['nombre']} · ${d['dosis']}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                                '${d['fecha_hora_programada'].toString().substring(11, 16)}  ·  ${d['estado']}')))),
              ),
          ]),
    );
  }
}

// ---------- Medicamentos: dosis diarias + lista (Fig. 13, 15) ----------
class MedsTab extends StatefulWidget {
  const MedsTab({super.key});
  @override
  State<MedsTab> createState() => _MedsState();
}

class _MedsState extends State<MedsTab> {
  List doses = [], meds = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final d = await Api.get('/doses?date=${fmt(DateTime.now())}'),
          m = await Api.get('/meds?estado=activo');
      if (mounted)
        setState(() {
          doses = d;
          meds = m;
        });
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> mark(int id, String st) async {
    try {
      await Api.post('/doses/$id/status', {'estado': st});
      await load();
    } catch (e) {
      if (mounted) snack(context, e);
      return;
    }
    await _synchronizeReminders();
  }

  Future<void> _synchronizeReminders() async {
    try {
      await DoseReminderService.instance.synchronizePendingDoses();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  void detail(Map m) => showModalBottomSheet(
      context: context,
      builder: (c) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('DETALLES',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Medicamento: ${m['nombre']}'),
                Text('Dosis: ${m['dosis']}'),
                Text('Presentación: ${m['presentacion'] ?? '-'}'),
                Text('Vía: ${m['via'] ?? '-'}'),
                Text(
                    'Frecuencia: ${m['frecuencia'] ?? '-'}  ·  Horas: ${m['horas']}'),
                Text(
                    'Stock: ${m['cantidad_actual'] ?? 'sin registrar'} ${m['unidad'] ?? ''}'),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: OutlinedButton(
                          onPressed: () async {
                            Navigator.pop(c);
                            await edit(m);
                          },
                          child: const Text('Editar'))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: OutlinedButton(
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                                context: c,
                                builder: (d) => AlertDialog(
                                        title: const Text(
                                            '¿Desactivar medicamento?'),
                                        content: const Text(
                                            'Se conserva el historial y se detienen los nuevos recordatorios.'),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(d, false),
                                              child: const Text('No')),
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(d, true),
                                              child: const Text('Desactivar'))
                                        ]));
                            if (ok == true) {
                              await Api.del('/meds/${m['id_medicamento']}');
                              if (c.mounted) Navigator.pop(c);
                              await load();
                              await _synchronizeReminders();
                            }
                          },
                          child: const Text('Desactivar'))),
                ]),
              ])));

  Future<void> edit(Map? m) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => MedForm(med: m)));
    await load();
    await _synchronizeReminders();
  }

  @override
  Widget build(BuildContext c) => RefreshIndicator(
      onRefresh: load,
      child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const Text('Dosis de hoy',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            if (doses.isEmpty)
              Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE8EFF4))),
                  child: const Row(children: [
                    Icon(Icons.event_available_outlined, color: kBlue),
                    SizedBox(width: 12),
                    Expanded(
                        child: Text('No hay dosis pendientes para hoy.',
                            style: TextStyle(fontWeight: FontWeight.w600))),
                  ])),
            for (final d in doses)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                    child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        leading: Container(
                            width: 54,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: const Color(0xFFF0F6FA),
                                borderRadius: BorderRadius.circular(12)),
                            child: Text(
                                d['fecha_hora_programada']
                                    .toString()
                                    .substring(11, 16),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: kBlue))),
                        title: Text('${d['nombre']} · ${d['dosis']}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        trailing: d['estado'] == 'pendiente'
                            ? PopupMenuButton<String>(
                                tooltip: 'Registrar dosis',
                                onSelected: (s) => mark(d['id_dosis'], s),
                                icon: const Icon(Icons.more_horiz_rounded),
                                itemBuilder: (_) => const [
                                      PopupMenuItem(
                                          value: 'tomada',
                                          child: Text('✓  Marcar tomada')),
                                      PopupMenuItem(
                                          value: 'omitida',
                                          child: Text('○  Marcar omitida')),
                                      PopupMenuItem(
                                          value: 'pospuesta',
                                          child: Text('◷  Posponer 10 min'))
                                    ])
                            : CircleAvatar(
                                radius: 16,
                                backgroundColor: d['estado'] == 'tomada'
                                    ? const Color(0xFFE8F5E9)
                                    : const Color(0xFFF1F3F4),
                                child: Icon(stIcon(d['estado']),
                                    size: 20,
                                    color: d['estado'] == 'tomada'
                                        ? Colors.green
                                        : Colors.grey)))),
              ),
            const SizedBox(height: 12),
            const Text('Mis medicamentos',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            if (meds.isEmpty)
              const Card(
                  child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Aún no tienes medicamentos registrados.',
                          textAlign: TextAlign.center))),
            for (final m in meds)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                    child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE3F2FD),
                            child:
                                Icon(Icons.medication_rounded, color: kBlue)),
                        title: Text(m['nombre'],
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${m['dosis']}  ·  ${m['horas']}'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => detail(m))),
              ),
            bigButton('Agregar medicamento', () => edit(null), color: kBlue),
          ]));
}

// ---------- Agregar / editar medicamento (Fig. 16) ----------
class MedForm extends StatefulWidget {
  final Map? med;
  const MedForm({super.key, this.med});
  @override
  State<MedForm> createState() => _MedFormState();
}

class _MedFormState extends State<MedForm> {
  late final Map m = widget.med ?? {};
  late final nom = TextEditingController(text: m['nombre']),
      dos = TextEditingController(text: m['dosis']),
      pre = TextEditingController(text: m['presentacion']),
      fre = TextEditingController(text: m['frecuencia']),
      stk = TextEditingController(text: m['cantidad_actual']?.toString()),
      min = TextEditingController(text: m['minimo']?.toString());
  late DateTime startDate = _dateValue(m['fecha_inicio']) ?? DateTime.now();
  late DateTime? endDate = _dateValue(m['fecha_fin']);
  late String route = m['via']?.toString() ?? 'oral';
  late int intervalHours =
      int.tryParse(m['intervalo_horas']?.toString() ?? '') ?? 0;
  late Set<int> weekdays = (m['dias_semana']?.toString() ?? '')
      .split(',')
      .where((day) => day.isNotEmpty)
      .map(int.tryParse)
      .whereType<int>()
      .where((day) => day >= DateTime.monday && day <= DateTime.sunday)
      .toSet();
  late List<TimeOfDay> times = (m['horas']?.toString() ?? '')
      .split(',')
      .map(_parseTime)
      .whereType<TimeOfDay>()
      .toList()
    ..sort(_compareTimes);
  bool saving = false;

  static DateTime? _dateValue(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static TimeOfDay? _parseTime(String value) {
    final parts = value.trim().split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  static int _compareTimes(TimeOfDay a, TimeOfDay b) =>
      (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute);

  static int _serverWeekday(int day) => day == DateTime.sunday ? 0 : day;

  static String _dateString(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static String _displayDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  static const weekdayLabels = {
    DateTime.monday: 'Lun',
    DateTime.tuesday: 'Mar',
    DateTime.wednesday: 'Mié',
    DateTime.thursday: 'Jue',
    DateTime.friday: 'Vie',
    DateTime.saturday: 'Sáb',
    DateTime.sunday: 'Dom',
  };

  Future<void> _addTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (selected == null || !mounted) return;
    if (times.any((time) =>
        time.hour == selected.hour && time.minute == selected.minute)) {
      snack(context, 'Ese horario ya está agregado.');
      return;
    }
    setState(() {
      times = intervalHours > 0 ? [selected] : [...times, selected]
        ..sort(_compareTimes);
    });
  }

  Future<void> _pickDate({required bool isEndDate}) async {
    final initial = isEndDate ? endDate ?? startDate : startDate;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText:
          isEndDate ? 'Selecciona la fecha de fin' : 'Selecciona el inicio',
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (isEndDate) {
        endDate = selected;
      } else {
        startDate = selected;
        if (endDate != null && endDate!.isBefore(startDate)) {
          endDate = startDate;
        }
      }
    });
  }

  Future<void> save() async {
    if (nom.text.trim().isEmpty || dos.text.trim().isEmpty) {
      snack(context, 'Escribe el nombre del medicamento y la dosis.');
      return;
    }
    if (times.isEmpty) {
      snack(context, 'Agrega al menos un horario para el tratamiento.');
      return;
    }
    if (endDate != null && endDate!.isBefore(startDate)) {
      snack(context, 'La fecha de fin no puede ser anterior a la de inicio.');
      return;
    }

    setState(() => saving = true);
    try {
      final body = {
        'nombre': nom.text.trim(),
        'dosis': dos.text.trim(),
        'presentacion': pre.text.trim(),
        'frecuencia': fre.text.trim(),
        'via': route,
        'horas': times
            .map((time) =>
                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}')
            .toList(),
        'fecha_inicio': _dateString(startDate),
        if (endDate != null) 'fecha_fin': _dateString(endDate!),
        if (intervalHours > 0) 'intervalo_horas': intervalHours,
        if (intervalHours == 0 && weekdays.isNotEmpty)
          'dias_semana': weekdays.map(_serverWeekday).toList()..sort(),
        if (stk.text.isNotEmpty) 'cantidad': int.tryParse(stk.text) ?? -1,
        if (min.text.isNotEmpty) 'minimo': int.tryParse(min.text) ?? 0,
      };
      m['id_medicamento'] == null
          ? await Api.post('/meds', body)
          : await Api.put('/meds/${m['id_medicamento']}', body);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) snack(context, e);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    nom.dispose();
    dos.dispose();
    pre.dispose();
    fre.dispose();
    stk.dispose();
    min.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) =>
      page(m.isEmpty ? 'Agregar medicamento' : 'Editar medicamento', [
        const Text(
          'Información del medicamento',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        field(nom, 'Nombre del medicamento', hint: 'Ej.: Medicamento'),
        field(dos, 'Dosis', hint: 'Ej.: 500 mg o 1 tableta'),
        field(pre, 'Presentación (opcional)', hint: 'Ej.: Tabletas'),
        DropdownButtonFormField<String>(
          initialValue: route,
          decoration: const InputDecoration(labelText: 'Vía de administración'),
          items: const [
            DropdownMenuItem(value: 'oral', child: Text('Oral')),
            DropdownMenuItem(value: 'tópica', child: Text('Tópica')),
            DropdownMenuItem(value: 'inhalatoria', child: Text('Inhalatoria')),
            DropdownMenuItem(value: 'subcutánea', child: Text('Subcutánea')),
            DropdownMenuItem(
                value: 'intramuscular', child: Text('Intramuscular')),
            DropdownMenuItem(value: 'otra', child: Text('Otra')),
          ],
          onChanged: (value) {
            if (value != null) setState(() => route = value);
          },
        ),
        field(fre, 'Indicaciones (opcional)', hint: 'Ej.: Con alimentos'),
        const SizedBox(height: 18),
        const Text(
          'Horario del tratamiento',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<int>(
          initialValue: intervalHours,
          decoration:
              const InputDecoration(labelText: 'Frecuencia de las dosis'),
          items: const [
            DropdownMenuItem(value: 0, child: Text('A horas específicas')),
            DropdownMenuItem(value: 4, child: Text('Cada 4 horas')),
            DropdownMenuItem(value: 6, child: Text('Cada 6 horas')),
            DropdownMenuItem(value: 8, child: Text('Cada 8 horas')),
            DropdownMenuItem(value: 12, child: Text('Cada 12 horas')),
            DropdownMenuItem(value: 24, child: Text('Cada 24 horas')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                intervalHours = value;
                if (value > 0 && times.length > 1) times = [times.first];
              });
            }
          },
        ),
        const SizedBox(height: 12),
        if (intervalHours == 0) ...[
          const Text('Días de la semana'),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            children: [
              for (final entry in weekdayLabels.entries)
                FilterChip(
                  label: Text(entry.value),
                  selected: weekdays.contains(entry.key),
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      weekdays.add(entry.key);
                    } else {
                      weekdays.remove(entry.key);
                    }
                  }),
                ),
            ],
          ),
          const Text(
            'Si no eliges días, el recordatorio se repetirá todos los días.',
            style: TextStyle(color: Color(0xFF657786)),
          ),
        ] else
          const Text(
            'El intervalo empieza a partir del primer horario que agregues.',
            style: TextStyle(color: Color(0xFF657786)),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final time in times)
              InputChip(
                avatar: const Icon(Icons.access_time_rounded, size: 18),
                label: Text(time.format(c)),
                onDeleted: () => setState(() => times.remove(time)),
              ),
            ActionChip(
              avatar: const Icon(Icons.add_rounded),
              label: const Text('Agregar hora'),
              onPressed: _addTime,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Duración del tratamiento',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        Card(
          child: Column(
            children: [
              ListTile(
                leading:
                    const Icon(Icons.calendar_today_outlined, color: kBlue),
                title: const Text('Fecha de inicio'),
                subtitle: Text(_displayDate(startDate)),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: () => _pickDate(isEndDate: false),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.event_busy_outlined, color: kBlue),
                title: const Text('Fecha de fin'),
                subtitle: Text(endDate == null
                    ? 'Sin fecha de fin'
                    : _displayDate(endDate!)),
                trailing: endDate == null
                    ? const Icon(Icons.add_rounded)
                    : IconButton(
                        tooltip: 'Quitar fecha de fin',
                        onPressed: () => setState(() => endDate = null),
                        icon: const Icon(Icons.close_rounded),
                      ),
                onTap: () => _pickDate(isEndDate: true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Inventario (opcional)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        Row(children: [
          Expanded(
              child: field(stk, 'Cantidad disponible',
                  keyboardType: TextInputType.number)),
          const SizedBox(width: 8),
          Expanded(
              child: field(min, 'Mínimo de alerta',
                  keyboardType: TextInputType.number))
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: saving ? null : () => Navigator.pop(c),
              child: const Text('Cancelar'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: saving ? null : save,
              child: Text(saving ? 'Guardando...' : 'Guardar tratamiento'),
            ),
          ),
        ]),
      ]);
}
