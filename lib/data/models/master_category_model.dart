import 'package:flutter/material.dart';

/// Modelo de dados para Categorias Mestres Dinâmicas da Luxpryme
/// (ex: Eletrônica, Produção, Outros, Preparação, Embalamento, etc.)
class MasterCategoryModel {
  final String id;
  final String name;
  final String? description;
  final String? colorHex;
  final String? iconName;
  final DateTime? createdAt;
  final bool isSystemDefault;

  const MasterCategoryModel({
    required this.id,
    required this.name,
    this.description,
    this.colorHex,
    this.iconName,
    this.createdAt,
    this.isSystemDefault = false,
  });

  factory MasterCategoryModel.fromMap(Map<String, dynamic> map) {
    final rawId = (map['id']?.toString() ?? '').toLowerCase().trim();
    return MasterCategoryModel(
      id: rawId,
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString(),
      colorHex: map['color']?.toString() ?? map['color_hex']?.toString(),
      iconName: map['icon']?.toString() ?? map['icon_name']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      isSystemDefault: map['is_system_default'] == true ||
          const ['eletronica', 'producao', 'outros'].contains(rawId),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      if (description != null) 'description': description,
      if (colorHex != null) 'color': colorHex,
      if (iconName != null) 'icon': iconName,
      'is_system_default': isSystemDefault,
    };
  }

  Color get color {
    if (colorHex != null && colorHex!.isNotEmpty) {
      try {
        final cleanHex = colorHex!.replaceAll('#', '');
        return Color(int.parse('FF$cleanHex', radix: 16));
      } catch (_) {}
    }
    switch (id.toLowerCase()) {
      case 'eletronica':
        return const Color(0xFF2563EB); // Azul Luxpryme
      case 'producao':
        return const Color(0xFF059669); // Verde Esmeralda
      case 'outros':
        return const Color(0xFF64748B); // Cinza Ardósia
      case 'preparacao':
        return const Color(0xFFEA580C); // Laranja Intenso
      case 'embalamento':
        return const Color(0xFF7C3AED); // Roxo
      default:
        return const Color(0xFF0284C7); // Azul Oceano
    }
  }

  IconData get icon {
    switch (iconName?.toLowerCase() ?? id.toLowerCase()) {
      case 'memory':
      case 'eletronica':
        return Icons.memory;
      case 'precision_manufacturing':
      case 'producao':
        return Icons.precision_manufacturing_outlined;
      case 'inventory_2':
      case 'outros':
        return Icons.inventory_2_outlined;
      case 'build':
      case 'preparacao':
        return Icons.build_outlined;
      case 'all_inbox':
      case 'archive':
      case 'embalamento':
      case 'embalagem':
        return Icons.all_inbox_outlined;
      case 'handyman':
        return Icons.handyman_outlined;
      case 'science':
        return Icons.science_outlined;
      case 'settings':
        return Icons.settings_outlined;
      case 'hardware':
        return Icons.hardware_outlined;
      case 'electrical_services':
        return Icons.electrical_services_outlined;
      case 'cable':
        return Icons.cable_outlined;
      default:
        return Icons.folder_special_outlined;
    }
  }

  MasterCategoryModel copyWith({
    String? id,
    String? name,
    String? description,
    String? colorHex,
    String? iconName,
    DateTime? createdAt,
    bool? isSystemDefault,
  }) {
    return MasterCategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      colorHex: colorHex ?? this.colorHex,
      iconName: iconName ?? this.iconName,
      createdAt: createdAt ?? this.createdAt,
      isSystemDefault: isSystemDefault ?? this.isSystemDefault,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MasterCategoryModel &&
          runtimeType == other.runtimeType &&
          id.toLowerCase() == other.id.toLowerCase();

  @override
  int get hashCode => id.toLowerCase().hashCode;
}
