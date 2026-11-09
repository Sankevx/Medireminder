import 'package:flutter/material.dart';
import '../api.dart';
import '../widgets.dart';
import 'home_screen.dart';

// ---------- Login / registro / recuperación (Fig. 6-8, 10) ----------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> {
  final em = TextEditingController(), pw = TextEditingController();
  bool remember = false, busy = false;
  Future<void> login() async {
    setState(() => busy = true);
    try {
      final r = await Api.post(
          '/auth/login', {'correo': em.text.trim(), 'password': pw.text});
      Api.token = r['token'];
      if (mounted)
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const Shell()));
    } catch (e) {
      if (mounted) snack(context, e);
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(Icons.medication_liquid_rounded,
                          size: 48, color: kBlue),
                    ),
                    const SizedBox(height: 20),
                    const Text('MediReminder',
                        style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF183B56))),
                    const SizedBox(height: 6),
                    Text('Cuida tus tratamientos a tiempo',
                        style: Theme.of(c)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: const Color(0xFF657786))),
                    const SizedBox(height: 32),
                    field(em, 'Correo electrónico',
                        keyboardType: TextInputType.emailAddress),
                    field(pw, 'Contraseña', obscure: true),
                    CheckboxListTile(
                        value: remember,
                        onChanged: (v) => setState(() => remember = v!),
                        title: const Text('Mantener sesión iniciada'),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero),
                    bigButton(busy ? 'Ingresando...' : 'Iniciar sesión',
                        busy ? null : login),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                          onPressed: () => Navigator.push(
                              c,
                              MaterialPageRoute(
                                  builder: (_) => const RecoverScreen())),
                          child: const Text('¿Olvidaste tu contraseña?')),
                    ),
                    const SizedBox(height: 8),
                    Row(children: const [
                      Expanded(child: Divider()),
                      Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('o')),
                      Expanded(child: Divider()),
                    ]),
                    const SizedBox(height: 12),
                    TextButton(
                        onPressed: () => Navigator.push(
                            c,
                            MaterialPageRoute(
                                builder: (_) => const RegisterScreen())),
                        child: const Text.rich(TextSpan(
                            text: '¿No tienes cuenta? ',
                            style: TextStyle(color: Color(0xFF657786)),
                            children: [
                              TextSpan(
                                  text: 'Crear cuenta',
                                  style: TextStyle(
                                      color: kBlue,
                                      fontWeight: FontWeight.w700))
                            ]))),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});
  @override
  Widget build(BuildContext c) {
    final n = TextEditingController(),
        e = TextEditingController(),
        t = TextEditingController(),
        p = TextEditingController();
    return page('Crear cuenta', [
      field(n, 'Nombre'),
      field(e, 'Correo', keyboardType: TextInputType.emailAddress),
      field(t, 'Teléfono (opcional)', keyboardType: TextInputType.phone),
      field(p, 'Contraseña (mín. 8)', obscure: true),
      bigButton('Registrarme', () async {
        try {
          await Api.post('/auth/register', {
            'nombre': n.text.trim(),
            'correo': e.text.trim(),
            'telefono': t.text.trim(),
            'password': p.text
          });
          if (c.mounted) {
            snack(c, 'Cuenta creada. Inicia sesión.');
            Navigator.pop(c);
          }
        } catch (x) {
          if (c.mounted) snack(c, x);
        }
      }),
    ]);
  }
}

class RecoverScreen extends StatefulWidget {
  const RecoverScreen({super.key});
  @override
  State<RecoverScreen> createState() => _RecoverState();
}

class _RecoverState extends State<RecoverScreen> {
  int step = 0;
  String? resetToken;
  bool developmentMode = false;
  final em = TextEditingController(),
      code = TextEditingController(),
      p1 = TextEditingController(),
      p2 = TextEditingController();
  bool busy = false;

  Future<void> next() async {
    if (busy) return;
    if (step == 0 &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(em.text.trim())) {
      snack(context, 'Ingresa un correo válido.');
      return;
    }
    if (step == 1 && !RegExp(r'^\d{4}$').hasMatch(code.text.trim())) {
      snack(context, 'El código debe tener 4 dígitos.');
      return;
    }
    if (step == 2) {
      if (p1.text.length < 8) {
        snack(context, 'La contraseña debe tener al menos 8 caracteres.');
        return;
      }
      if (p1.text != p2.text) {
        snack(context, 'Las contraseñas no coinciden.');
        return;
      }
    }

    setState(() => busy = true);
    try {
      if (step == 0) {
        final response =
            await Api.post('/auth/forgot', {'correo': em.text.trim()});
        developmentMode = response['developmentMode'] == true;
      } else if (step == 1) {
        resetToken = (await Api.post('/auth/verify', {
          'correo': em.text.trim(),
          'codigo': code.text.trim()
        }))['resetToken'];
      } else {
        await Api.post(
            '/auth/reset', {'resetToken': resetToken, 'password': p1.text});
        if (mounted) {
          snack(context, 'Contraseña actualizada. Inicia sesión.');
          Navigator.pop(context);
        }
        return;
      }
      setState(() => step++);
    } catch (e) {
      if (mounted) snack(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    em.dispose();
    code.dispose();
    p1.dispose();
    p2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => page('Recuperar contraseña', [
        Text(
          'Paso ${step + 1} de 3',
          style: const TextStyle(color: kBlue, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (step == 0) ...[
          const Text(
              'Ingresa el correo de tu cuenta. Te enviaremos un código que vence en 10 minutos.'),
          field(em, 'Correo', keyboardType: TextInputType.emailAddress),
        ],
        if (step == 1) ...[
          Text(
            developmentMode
                ? 'Modo de desarrollo: consulta el código en la consola con `docker compose logs -f api`.'
                : 'Ingresa el código de 4 dígitos que enviamos a tu correo. Revisa también la carpeta de correo no deseado.',
          ),
          field(code, 'Código de recuperación',
              keyboardType: TextInputType.number),
        ],
        if (step == 2) ...[
          const Text('Elige una contraseña nueva de al menos 8 caracteres.'),
          field(p1, 'Nueva contraseña (mín. 8)', obscure: true),
          field(p2, 'Confirma tu contraseña', obscure: true),
        ],
        bigButton(
          busy
              ? 'Procesando...'
              : [
                  'Enviar código',
                  'Verificar código',
                  'Guardar contraseña'
                ][step],
          busy ? null : next,
        ),
      ]);
}
