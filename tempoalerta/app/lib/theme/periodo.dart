import 'package:flutter/material.dart';

/// Tema muda conforme o horário: manhã (5-12), tarde (12-18), noite (18-5).
class Periodo {
  final String nome;
  final List<Color> gradiente;
  final Color card;
  const Periodo(this.nome, this.gradiente, this.card);

  static const manha = Periodo('Manhã',
      [Color(0xFF29A8E3), Color(0xFFC8E0EE)], Color(0x99337F90));
  static const tarde = Periodo('Tarde',
      [Color(0xFFDCC76E), Color(0xFF8DB88F), Color(0xFF2A9BA3)], Color(0x99306B64));
  static const noite = Periodo('Noite',
      [Color(0xFF0F2169), Color(0xFF3D4668), Color(0xFF555B66)], Color(0xFF2E78A6));

  static Periodo agora([DateTime? t]) {
    final h = (t ?? DateTime.now()).hour;
    if (h >= 5 && h < 12) return manha;
    if (h >= 12 && h < 18) return tarde;
    return noite;
  }
}
