import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/delivery_file.dart';
import '../../models/milestone.dart';
import '../../services/delivery_service.dart';
import '../../theme/app_colors.dart';

class SubmitDeliveryScreen extends StatefulWidget {
  final String contractId;

  const SubmitDeliveryScreen({
    super.key,
    this.contractId = 'CT-2026-0418',
  });

  @override
  State<SubmitDeliveryScreen> createState() => _SubmitDeliveryScreenState();
}

class _SubmitDeliveryScreenState extends State<SubmitDeliveryScreen> {
  final DeliveryService _deliveryService = DeliveryService();
  final ImagePicker _imagePicker = ImagePicker();

  late List<Milestone> _milestones;
  late int _selectedMilestoneIndex;

  final TextEditingController _repoController = TextEditingController(
    text: 'github.com/afernandez/telemetria',
  );
  final TextEditingController _notesController = TextEditingController(
    text: 'Incluye migraciones SQL y ADR de TimescaleDB.',
  );

  final List<DeliveryFile> _attachedFiles = [];
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _milestones = _deliveryService.getInitialMilestones();
    _selectedMilestoneIndex = 0; // H1 por defecto

    // Pre-cargar dos archivos de ejemplo iniciales (del diseño de Figma)
    _attachedFiles.addAll([
      const DeliveryFile(
        name: 'ADR_arquitectura.pdf',
        sizeInBytes: 1024 * 1024 * 2 + 500 * 1024, // 2.5 MB
      ),
      const DeliveryFile(
        name: 'diagrama_C4.png',
        sizeInBytes: 850 * 1024, // 850 KB
      ),
    ]);
  }

  @override
  void dispose() {
    _repoController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Milestone get _currentMilestone => _milestones[_selectedMilestoneIndex];

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 90,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _attachedFiles.add(
            DeliveryFile(
              name: picked.name,
              path: picked.path,
              sizeInBytes: bytes.length,
            ),
          );
          _validationError = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al capturar imagen: $e')),
      );
    }
  }

  Future<void> _pickDocuments() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'zip', 'rar', 'png', 'jpg', 'jpeg'],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          for (var f in result.files) {
            _attachedFiles.add(
              DeliveryFile(
                name: f.name,
                path: f.path,
                sizeInBytes: f.size,
              ),
            );
          }
          _validationError = null;
        });
      }
    } catch (_) {
      // Fallback seguro si la plataforma restringe el explorador nativo en simulador
      _addSampleFile('entrega_tecnica_comprimida.zip', 4 * 1024 * 1024);
    }
  }

  void _addSampleFile(String name, int size) {
    setState(() {
      _attachedFiles.add(DeliveryFile(name: name, sizeInBytes: size));
      _validationError = null;
    });
  }

  void _showAttachmentSourceModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Adjuntar Evidencia',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    child: Icon(Icons.picture_as_pdf, color: AppColors.primary),
                  ),
                  title: Text('Seleccionar Archivos (PDF, ZIP, docs)',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  subtitle: Text('Soporta archivos de hasta 25 MB',
                      style: GoogleFonts.poppins(fontSize: 11.5)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickDocuments();
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    child: Icon(Icons.photo_library, color: AppColors.primary),
                  ),
                  title: Text('Galería de Imágenes',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    child: Icon(Icons.camera_alt, color: AppColors.primary),
                  ),
                  title: Text('Tomar Foto con Cámara',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _validateAndSubmit() {
    final repo = _repoController.text.trim();

    // Criterio de validación: debe haber al menos un archivo adjunto o enlace válido
    if (_attachedFiles.isEmpty && repo.isEmpty) {
      setState(() {
        _validationError = 'Adjunta al menos una evidencia.';
      });
      return;
    }

    setState(() => _validationError = null);
    _showConfirmDialog();
  }

  void _showConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            '¿Enviar a revisión?',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          content: Text(
            '${_attachedFiles.length} archivos adjuntos. Se notificará a ${_currentMilestone.clientName} y tendrá ${_currentMilestone.reviewDays} días hábiles para revisar.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancelar',
                style: GoogleFonts.poppins(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _performUpload();
              },
              child: Text(
                'Sí, enviar',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performUpload() async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.05;
    });

    final result = await _deliveryService.submitDelivery(
      milestoneId: _currentMilestone.id,
      repositoryUrl: _repoController.text.trim(),
      technicalNotes: _notesController.text.trim(),
      files: _attachedFiles,
      onProgress: (p) {
        if (mounted) setState(() => _uploadProgress = p);
      },
    );

    if (!mounted) return;

    setState(() => _isUploading = false);

    if (result.success) {
      _showSuccessDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF2E7D32),
                    size: 38,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Hito en revisión',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tu entrega fue enviada con éxito.\nRevisión en ${_currentMilestone.reviewDays} días hábiles.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context); // Vuelve a la pantalla previa
                    },
                    child: Text(
                      'Entendido',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMilestoneSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => Navigator.pop(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back_ios, size: 13, color: Color(0xFF6B4A55)),
                      Text(
                        ' ${widget.contractId}',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF6B4A55),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Entregar hito',
            style: GoogleFonts.dmSans(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          // Chips H1 Fondeado vs H2 Sin fondeo
          Row(
            children: List.generate(_milestones.length, (index) {
              final m = _milestones[index];
              final isSelected = _selectedMilestoneIndex == index;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedMilestoneIndex = index;
                      _validationError = null;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primary,
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      '${m.label} · ${m.isFunded ? "Fondeado" : "Sin fondeo"}',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : AppColors.primary,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedUnfundedState() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5D9CB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_clock_rounded,
              size: 42,
              color: Color(0xFF7A1F3D),
            ),
            const SizedBox(height: 12),
            Text(
              'Hito sin fondeo',
              style: GoogleFonts.dmSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF3A1020),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'El cliente aún no deposita los fondos del ${_currentMilestone.label}. No puedes enviar entregas hasta que esté fondeado en custodia (Escrow).',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: const Color(0xFF6B4A55),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  setState(() => _selectedMilestoneIndex = 0);
                },
                child: Text(
                  'Volver al H1',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Zona para adjuntar evidencias
          InkWell(
            onTap: _showAttachmentSourceModal,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _validationError != null
                      ? Colors.redAccent
                      : const Color(0xFFE5D9CB),
                  width: 1.4,
                ),
              ),
              child: Column(
                children: [
                  const Icon(Icons.cloud_upload_outlined,
                      size: 36, color: AppColors.primary),
                  const SizedBox(height: 8),
                  Text(
                    '+ Adjuntar evidencia',
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'PDF, imágenes o ZIP (Hasta 25 MB)',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Error de validación de evidencia faltante
          if (_validationError != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.error_outline, size: 14, color: Colors.redAccent),
                const SizedBox(width: 4),
                Text(
                  _validationError!,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Listado de archivos adjuntos
          if (_attachedFiles.isNotEmpty) ...[
            ..._attachedFiles.map((file) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5D9CB)),
                ),
                child: Row(
                  children: [
                    Icon(
                      file.isPdf
                          ? Icons.picture_as_pdf
                          : file.isZip
                              ? Icons.archive
                              : Icons.image,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            file.formattedSize,
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _attachedFiles.remove(file);
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          'Quitar',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF7A1F3D),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
          ],

          // Campo: Enlace al repositorio
          Text(
            'Enlace al repositorio',
            style: GoogleFonts.dmSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5D9CB)),
            ),
            child: TextField(
              controller: _repoController,
              decoration: InputDecoration(
                hintText: 'ej. github.com/usuario/proyecto',
                hintStyle: GoogleFonts.dmSans(fontSize: 13, color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.link, size: 20, color: AppColors.textSecondary),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Campo: Notas técnicas
          Text(
            'Notas técnicas',
            style: GoogleFonts.dmSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5D9CB)),
            ),
            child: TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Detalles técnicos de la entrega, instrucciones de despliegue...',
                hintStyle: GoogleFonts.dmSans(fontSize: 13, color: Colors.grey.shade400),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Barra de progreso visual durante subida multipart
          if (_isUploading) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primaryLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Subiendo evidencias multipart...',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        '${(_uploadProgress * 100).toInt()}%',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _uploadProgress,
                    backgroundColor: AppColors.primaryLight,
                    color: AppColors.primary,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Botón principal: Solicitar revisión
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: Colors.grey.shade300,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _isUploading ? null : _validateAndSubmit,
              child: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Solicitar revisión',
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      body: SafeArea(
        child: Column(
          children: [
            _buildMilestoneSelector(),
            Expanded(
              child: _currentMilestone.isFunded
                  ? _buildFormBody()
                  : _buildBlockedUnfundedState(),
            ),
          ],
        ),
      ),
    );
  }
}
