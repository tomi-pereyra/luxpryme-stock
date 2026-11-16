import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

enum LuxLogoVariant {
  /// Letra 'L' azul médio em fundo branco (conforme especificação principal)
  blueOnWhite,

  /// Letra 'L' branca em fundo azul médio
  whiteOnBlue,
}

class LuxLogo extends StatelessWidget {
  final double size;
  final LuxLogoVariant variant;
  final bool showBrandName;
  final bool isDarkBackground;

  const LuxLogo({
    super.key,
    this.size = 72,
    this.variant = LuxLogoVariant.blueOnWhite,
    this.showBrandName = true,
    this.isDarkBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isBlueOnWhite = variant == LuxLogoVariant.blueOnWhite;
    final Color bgColor = isBlueOnWhite ? Colors.white : AppColors.primary;
    final Color letterColor = isBlueOnWhite ? AppColors.primary : Colors.white;

    final Color titleColor = isDarkBackground ? Colors.white : AppColors.textPrimary;
    final Color subtitleColor = isDarkBackground ? Colors.white70 : AppColors.textSecondary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Símbolo do Logotipo: "L" destacado e minimalista
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(size * 0.22),
            border: isBlueOnWhite
                ? Border.all(color: AppColors.border, width: 1.5)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            'L',
            style: GoogleFonts.montserrat(
              fontSize: size * 0.62,
              fontWeight: FontWeight.w900,
              color: letterColor,
              letterSpacing: -1.0,
            ),
          ),
        ),
        if (showBrandName) ...[
          const SizedBox(height: 12),
          Text(
            'LUXPRYME',
            style: GoogleFonts.inter(
              fontSize: size * 0.32,
              fontWeight: FontWeight.w800,
              letterSpacing: 3.5,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'STOCK',
            style: GoogleFonts.inter(
              fontSize: size * 0.18,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.5,
              color: subtitleColor,
            ),
          ),
        ],
      ],
    );
  }
}
