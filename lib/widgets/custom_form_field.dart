import 'package:flutter/material.dart';

/// Um widget de campo de formulário reutilizável para manter a consistência visual.
class CustomFormField extends StatelessWidget {
  final String labelText;
  final bool isPassword;
  final IconData? icon;

  const CustomFormField({
    super.key,
    required this.labelText,
    this.isPassword = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      obscureText: isPassword,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: icon != null ? Icon(icon, color: Colors.white70) : null,
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white54),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white),
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.purple[700]?.withOpacity(0.5),
      ),
      style: const TextStyle(color: Colors.white),
      // Adicionar validador e controller no futuro
    );
  }
}