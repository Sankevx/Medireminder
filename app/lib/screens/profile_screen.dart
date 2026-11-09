import 'package:flutter/material.dart';

import '../accessibility_settings.dart';
import '../api.dart';
import '../dose_reminder_service.dart';
import '../widgets.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmSignOut(BuildContext context) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.logout_rounded, color: kBlue),
        title: const Text('Cerrar sesión'),
        content: const Text('¿Quieres salir de tu cuenta de MediReminder?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (shouldSignOut != true || !context.mounted) return;
    try {
      await DoseReminderService.instance.cancelAll();
    } catch (error) {
      if (context.mounted) snack(context, error);
    }
    if (!context.mounted) return;
    Api.token = null;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Perfil')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 8),
            const CircleAvatar(
              radius: 38,
              backgroundColor: Color(0xFFE3F2FD),
              child: Icon(Icons.person_outline, size: 42, color: kBlue),
            ),
            const SizedBox(height: 12),
            Text(
              'Tu perfil',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            const Text(
              'Personaliza la app para que te resulte más cómoda.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE3F2FD),
                  child: Icon(Icons.accessibility_new_rounded, color: kBlue),
                ),
                title: const Text('Accesibilidad'),
                subtitle: const Text('Texto, contraste y movimiento'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AccessibilityScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFEBEE),
                  child: Icon(Icons.logout_rounded, color: Colors.redAccent),
                ),
                title: const Text('Cerrar sesión'),
                subtitle: const Text('Salir de tu cuenta de forma segura'),
                onTap: () => _confirmSignOut(context),
              ),
            ),
          ],
        ),
      );
}

class AccessibilityScreen extends StatelessWidget {
  const AccessibilityScreen({super.key});

  Future<void> _save(
    BuildContext context,
    Future<void> Function() update,
  ) async {
    try {
      await update();
    } catch (error) {
      if (context.mounted) snack(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = AccessibilitySettings.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Accesibilidad')),
      body: AnimatedBuilder(
        animation: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Ajusta la app a tus necesidades',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            const Text(
              'Estos cambios se aplican en toda la aplicación y se guardan en este dispositivo.',
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.text_fields_rounded, color: kBlue),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Tamaño del texto',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text('${(settings.textScale * 100).round()}%'),
                      ],
                    ),
                    Slider(
                      value: settings.textScale,
                      min: 1,
                      max: 1.8,
                      divisions: 4,
                      label: '${(settings.textScale * 100).round()}%',
                      semanticFormatterCallback: (value) =>
                          'Tamaño del texto ${(value * 100).round()} por ciento',
                      onChanged: (value) => _save(
                        context,
                        () => settings.setTextScale(value),
                      ),
                    ),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Estándar'),
                        Text('Más grande'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Vista previa: toma tu medicamento a la hora indicada.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: SwitchListTile(
                secondary: const Icon(Icons.contrast_rounded, color: kBlue),
                title: const Text('Alto contraste'),
                subtitle: const Text(
                  'Usa colores más definidos para facilitar la lectura.',
                ),
                value: settings.highContrast,
                onChanged: (value) => _save(
                  context,
                  () => settings.setHighContrast(value),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: SwitchListTile(
                secondary: const Icon(
                  Icons.motion_photos_off_rounded,
                  color: kBlue,
                ),
                title: const Text('Reducir movimiento'),
                subtitle: const Text(
                  'Reduce las animaciones y transiciones de la app.',
                ),
                value: settings.reduceMotion,
                onChanged: (value) => _save(
                  context,
                  () => settings.setReduceMotion(value),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'También puedes usar las opciones de accesibilidad de Android, como TalkBack y el tamaño de pantalla.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
