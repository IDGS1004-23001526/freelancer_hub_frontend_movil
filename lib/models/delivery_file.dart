import 'dart:io';

class DeliveryFile {
  final String name;
  final String? path;
  final int sizeInBytes;

  const DeliveryFile({
    required this.name,
    this.path,
    required this.sizeInBytes,
  });

  bool get isImage {
    final ext = name.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext);
  }

  bool get isPdf => name.toLowerCase().endsWith('.pdf');
  bool get isZip => name.toLowerCase().endsWith('.zip') || name.toLowerCase().endsWith('.rar');

  double get sizeInMb => sizeInBytes / (1024 * 1024);

  String get formattedSize {
    if (sizeInBytes < 1024) return '$sizeInBytes B';
    if (sizeInBytes < 1024 * 1024) return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    return '${sizeInMb.toStringAsFixed(1)} MB';
  }

  File? toFile() {
    if (path == null) return null;
    return File(path!);
  }
}
