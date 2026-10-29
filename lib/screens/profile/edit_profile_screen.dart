import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/user_profile.dart';
import '../../services/profile_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/form_validators.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';

class EditProfileScreen extends StatefulWidget {
  final UserProfile user;
  final ProfileService? profileService;

  const EditProfileScreen({
    super.key,
    required this.user,
    this.profileService,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProfileService _defaultProfileService = ProfileService();
  ProfileService get _profileService => widget.profileService ?? _defaultProfileService;
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _roleController;
  late TextEditingController _locationController;
  late TextEditingController _bioController;

  File? _localImageFile;
  String? _currentAvatarUrl;
  late List<String> _selectedSkills;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;

  final List<String> _freelancerSkills = [
    'Flutter',
    'Dart',
    'UI/UX',
    'Figma',
    'Backend',
    'PostgreSQL',
    'Node.js',
    'REST APIs',
    'Git',
    'TypeScript',
    'Prisma',
    'Docker',
  ];

  final List<String> _clientPreferences = [
    'Desarrollo Móvil',
    'Diseño UI/UX',
    'Desarrollo Web Fullstack',
    'Bases de Datos & Cloud',
    'Consultoría Tecnológica',
    'Mantenimiento & Soporte',
  ];

  bool get _isFreelancer => widget.user.role.toUpperCase() != 'CLIENT';

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.user.firstName);
    _lastNameController = TextEditingController(text: widget.user.lastName);
    _phoneController = TextEditingController(text: widget.user.phone);
    _roleController = TextEditingController(text: widget.user.role);
    _locationController = TextEditingController(text: widget.user.location);
    _bioController = TextEditingController(text: widget.user.bio);
    _currentAvatarUrl = widget.user.avatarUrl;
    _selectedSkills = List.from(widget.user.skills);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _roleController.dispose();
    _locationController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  /// Escenario 3: Carga y actualización de foto de avatar (JPG/PNG ≤ 2 MB)
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (file == null) return;

      // 1. Validar formato de archivo (JPG / PNG)
      final lowerPath = file.path.toLowerCase();
      final isValidExtension = lowerPath.endsWith('.jpg') ||
          lowerPath.endsWith('.jpeg') ||
          lowerPath.endsWith('.png');

      if (!isValidExtension) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
              'Formato no permitido: La imagen debe ser formato JPG o PNG.',
            ),
          ),
        );
        return;
      }

      // 2. Validar tamaño máximo de 2 MB (2 * 1024 * 1024 bytes)
      final int fileBytes = await file.length();
      const int maxBytes = 2 * 1024 * 1024; // 2 MB

      if (fileBytes > maxBytes) {
        final mbSize = (fileBytes / (1024 * 1024)).toStringAsFixed(2);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
              'La imagen supera el límite de 2 MB (tamaño actual: $mbSize MB). Por favor selecciona otra.',
            ),
          ),
        );
        return;
      }

      // 3. Procesar y subir imagen al backend actualizando la UI sin recargar
      final imageFile = File(file.path);
      setState(() {
        _localImageFile = imageFile;
        _isUploadingAvatar = true;
      });

      final uploadedUrl = await _profileService.uploadAvatar(imageFile);

      if (!mounted) return;
      setState(() {
        _isUploadingAvatar = false;
        if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
          _currentAvatarUrl = uploadedUrl;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text('Foto de perfil actualizada correctamente.'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al procesar la imagen: $e')),
      );
    }
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.primary),
                title: Text('Tomar foto con la cámara',
                    style: GoogleFonts.poppins()),
                subtitle: Text('JPG o PNG ≤ 2 MB',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.photo_library, color: AppColors.primary),
                title:
                    Text('Elegir de la galería', style: GoogleFonts.poppins()),
                subtitle: Text('JPG o PNG ≤ 2 MB',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Escenario 2: Guardado exitoso de información general
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    String? finalAvatarUrl = _currentAvatarUrl ?? widget.user.avatarUrl;

    if (_localImageFile != null && (_currentAvatarUrl == null || _currentAvatarUrl == widget.user.avatarUrl)) {
      final uploaded = await _profileService.uploadAvatar(_localImageFile!);
      if (uploaded != null) {
        finalAvatarUrl = uploaded;
      }
    }

    final String firstName = _firstNameController.text.trim();
    final String lastName = _lastNameController.text.trim();
    final String fullName = '$firstName $lastName'.trim();

    final updated = widget.user.copyWith(
      firstName: firstName,
      lastName: lastName,
      fullName: fullName,
      phone: _phoneController.text.trim(),
      role: _roleController.text.trim().isNotEmpty ? _roleController.text.trim() : widget.user.role,
      location: _locationController.text.trim(),
      bio: _bioController.text.trim(),
      avatarUrl: finalAvatarUrl,
      skills: _selectedSkills,
    );

    final success = await _profileService.updateProfile(updated);

    setState(() => _isSaving = false);

    if (!mounted) return;

    if (success) {
      // Notificar éxito al usuario
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text('¡Perfil actualizado con éxito!'),
          duration: Duration(seconds: 2),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.pop(context, updated);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Error al guardar datos en el servidor'),
        ),
      );
    }
  }

  Widget _buildAvatarWidget() {
    if (_localImageFile != null) {
      return Image.file(_localImageFile!,
          width: 110, height: 110, fit: BoxFit.cover);
    }
    if (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty) {
      return Image.network(
        _currentAvatarUrl!,
        width: 110,
        height: 110,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 110,
      height: 110,
      color: AppColors.primaryLight,
      child: const Icon(Icons.person, size: 60, color: AppColors.primary),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableOptions = _isFreelancer ? _freelancerSkills : _clientPreferences;
    final optionsTitle = _isFreelancer ? 'Habilidades Técnicas' : 'Preferencias de Contratación';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Editar Perfil',
          style: GoogleFonts.poppins(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: Text(
              'Guardar',
              style: GoogleFonts.poppins(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar interactivo
                Center(
                  child: Stack(
                    children: [
                      ClipOval(child: _buildAvatarWidget()),
                      if (_isUploadingAvatar)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _isUploadingAvatar ? null : _showImagePickerSheet,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt,
                                size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'JPG o PNG (máx. 2 MB)',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Escenario 1: Visualización de datos registrados previamente (correo, rol)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _isFreelancer
                              ? Icons.laptop_chromebook_outlined
                              : Icons.business_center_outlined,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.user.email.isNotEmpty
                                  ? widget.user.email
                                  : 'Cuenta activa FreelancerHub',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _isFreelancer ? 'FREELANCER' : 'CLIENTE',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Datos pre-llenados',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Escenario 2: Campos disponibles para completar
                Text(
                  'Información Personal',
                  style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  key: const Key('edit_first_name_field'),
                  controller: _firstNameController,
                  labelText: 'Nombre',
                  prefixIcon: Icons.person_outline,
                  validator: FormValidators.validateName,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  key: const Key('edit_last_name_field'),
                  controller: _lastNameController,
                  labelText: 'Apellidos',
                  prefixIcon: Icons.badge_outlined,
                  validator: FormValidators.validateLastName,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  key: const Key('edit_phone_field'),
                  controller: _phoneController,
                  labelText: 'Teléfono de contacto',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: FormValidators.validatePhone,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  key: const Key('edit_role_title_field'),
                  controller: _roleController,
                  labelText: _isFreelancer
                      ? 'Especialidad o Título profesional'
                      : 'Empresa o Razón de Contratación',
                  prefixIcon: Icons.work_outline,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Este campo es obligatorio'
                      : null,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  key: const Key('edit_location_field'),
                  controller: _locationController,
                  labelText: 'Ubicación (Ciudad, País)',
                  prefixIcon: Icons.location_on_outlined,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  key: const Key('edit_bio_field'),
                  controller: _bioController,
                  labelText: 'Biografía o Resumen profesional',
                  prefixIcon: Icons.description_outlined,
                  maxLines: 3,
                ),
                const SizedBox(height: 24),

                Text(
                  optionsTitle,
                  style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  _isFreelancer
                      ? 'Selecciona las habilidades que dominas para destacar ante clientes'
                      : 'Selecciona las áreas de especialidad que requieres para tus proyectos',
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: availableOptions.map((skill) {
                    final isSelected = _selectedSkills.contains(skill);
                    return FilterChip(
                      label: Text(skill),
                      selected: isSelected,
                      labelStyle: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        color:
                            isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      checkmarkColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border),
                      ),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedSkills.add(skill);
                          } else {
                            _selectedSkills.remove(skill);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
                PrimaryButton(
                  key: const Key('edit_profile_submit_button'),
                  text: 'Guardar Cambios',
                  isLoading: _isSaving,
                  onPressed: _saveProfile,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
