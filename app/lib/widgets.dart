import 'package:flutter/material.dart';

const kBlue = Color(0xFF1E88C7);

IconData stIcon(String status) =>
    {
      'tomada': Icons.check_circle,
      'omitida': Icons.cancel,
      'pospuesta': Icons.schedule,
    }[status] ??
    Icons.radio_button_unchecked;

String fmt(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

void snack(BuildContext context, Object message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message.toString().replaceFirst('Exception: ', ''),
      ),
    ),
  );
}

Widget field(
  TextEditingController controller,
  String label, {
  bool obscure = false,
  TextInputType? keyboardType,
  String? hint,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    ),
  );
}

Widget bigButton(String text, VoidCallback? onPressed, {Color? color}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: SizedBox(
      height: 52,
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color ?? kBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        onPressed: onPressed,
        child: Text(text),
      ),
    ),
  );
}

Widget page(String title, List<Widget> children) {
  return Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ListView(padding: const EdgeInsets.all(24), children: children),
  );
}
