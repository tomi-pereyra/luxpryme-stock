import 'package:flutter/material.dart';

/// Paleta de Cores Oficial da Marca Luxpryme
/// Identidade: Azul médio destacado, branco puro e cinzas industriais limpos.
class AppColors {
  AppColors._();

  // Azul Luxpryme (Azul Médio Tecnológico)
  static const Color primary = Color(0xFF1976D2); // Azul Médio Material
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color primaryLight = Color(0xFF64B5F6);
  static const Color primaryContainer = Color(0xFFE3F2FD);

  // Fundos e Superfícies
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);

  // Textos
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // Status de Estoque
  static const Color stockNormal = Color(0xFF059669); // Verde seguro
  static const Color stockLow = Color(0xFFD97706);    // Laranja atenção
  static const Color stockZero = Color(0xFFDC2626);   // Vermelho crítico

  // Bordas e Divisores
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);
}
