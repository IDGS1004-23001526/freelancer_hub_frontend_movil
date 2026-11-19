import 'dart:io';
import 'package:flutter/material.dart';
import '../config/api_constants.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';

/// Renderiza la imagen de avatar del usuario soportando:
/// 1. Archivo local activo [localFile]
/// 2. URL remota HTTP/HTTPS
/// 3. Ruta relativa del servidor backend (/uploads/...)
/// 4. Ruta persistida en el sistema de archivos del dispositivo (Android/iOS/PC)
/// 5. Placeholder con icono estilizado en caso de ausencia o error
class AvatarImage extends StatelessWidget {
  final String? avatarUrl;
  final File? localFile;
  final double size;

  const AvatarImage({
    super.key,
    this.avatarUrl,
    this.localFile,
    this.size = 90,
  });

  Widget _buildPlaceholder() {
    return Container(
      width: size,
      height: size,
      color: AppColors.primaryLight,
      child: Icon(
        Icons.person,
        size: size * 0.55,
        color: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (localFile != null && localFile!.existsSync()) {
      return Image.file(
        localFile!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }

    if (avatarUrl == null || avatarUrl!.trim().isEmpty) {
      return _buildPlaceholder();
    }

    final trimmed = avatarUrl!.trim();

    // URL absoluta remota
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Image.network(
        trimmed,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }

    // Ruta relativa servida por el backend (/uploads/...)
    if (trimmed.startsWith('/uploads/') || trimmed.startsWith('uploads/')) {
      final rawBase = AuthService.activeBaseUrl ?? ApiConstants.baseUrl;
      final hostBase = rawBase.replaceFirst(RegExp(r'/api/v1/?$'), '');
      final fullUrl =
          trimmed.startsWith('/') ? '$hostBase$trimmed' : '$hostBase/$trimmed';
      return Image.network(
        fullUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }

    // Ruta de archivo en el almacenamiento del dispositivo
    try {
      final cleanPath = trimmed.replaceFirst('file://', '');
      final file = File(cleanPath);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        );
      }
    } catch (_) {}

    return _buildPlaceholder();
  }
}
