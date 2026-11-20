import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/convocatoria.dart';
import '../../models/proposal.dart';
import '../../services/proposal_service.dart';
import '../../theme/app_colors.dart';
import 'proposal_submitted_screen.dart';

class _MilestoneDraft {
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController amountController;
  final TextEditingController daysController;

  _MilestoneDraft({
    String title = '',
    String description = '',
    String amount = '',
    String days = '',
  })  : titleController = TextEditingController(text: title),
        descriptionController = TextEditingController(text: description),
        amountController = TextEditingController(text: amount),
        daysController = TextEditingController(text: days);

  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    amountController.dispose();
    daysController.dispose();
  }
}

/// HU-03: Pantalla de Postulación y Cotización por Hitos (`ProposalSubmissionScreen`)
class ProposalSubmissionScreen extends StatefulWidget {
  final Convocatoria convocatoria;
  final ProposalService? proposalService;

  const ProposalSubmissionScreen({
    super.key,
    required this.convocatoria,
    this.proposalService,
  });

  @override
  State<ProposalSubmissionScreen> createState() =>
      _ProposalSubmissionScreenState();
}

class _ProposalSubmissionScreenState extends State<ProposalSubmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final ProposalService _proposalService;

  late final TextEditingController _totalAmountController;
  late final TextEditingController _estimatedDaysController;
  late final TextEditingController _coverLetterController;
  final FocusNode _coverLetterFocus = FocusNode();

  final List<_MilestoneDraft> _milestones = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _proposalService = widget.proposalService ?? ProposalService();

    final initialBudget =
        widget.convocatoria.budget > 0 ? widget.convocatoria.budget : 1000.0;
    final initialDays = widget.convocatoria.remainingDays > 0
        ? widget.convocatoria.remainingDays
        : 30;

    _totalAmountController = TextEditingController(
      text: _rawNumber(initialBudget),
    )..addListener(_onValuesChanged);

    _estimatedDaysController = TextEditingController(
      text: initialDays.toString(),
    )..addListener(_onValuesChanged);

    _coverLetterController = TextEditingController()
      ..addListener(_onValuesChanged);

    // Inicializar con 1 hito base igual al presupuesto para facilitar la edición
    _addMilestone(
      title: 'Entrega principal',
      description: '',
      amount: _rawNumber(initialBudget),
      days: initialDays.toString(),
      notify: false,
    );
  }

  @override
  void dispose() {
    _totalAmountController.dispose();
    _estimatedDaysController.dispose();
    _coverLetterController.dispose();
    _coverLetterFocus.dispose();
    for (final m in _milestones) {
      m.dispose();
    }
    super.dispose();
  }

  void _onValuesChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  double _parseAmount(String text) {
    final cleaned = text.replaceAll(',', '').replaceAll('\$', '').trim();
    return double.tryParse(cleaned) ?? 0.0;
  }

  int _parseDays(String text) {
    final cleaned = text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleaned) ?? 0;
  }

  String _rawNumber(double value) {
    return value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(2);
  }

  String _formatUsd(double value) {
    final absVal = value.abs();
    final isWhole = absVal == absVal.roundToDouble();
    final raw =
        isWhole ? absVal.round().toString() : absVal.toStringAsFixed(2);
    final parts = raw.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    final formatted = parts.length > 1 ? '\$$intPart.${parts[1]}' : '\$$intPart';
    return value < 0 ? '-$formatted' : formatted;
  }

  double get _totalOffered => _parseAmount(_totalAmountController.text);

  int get _estimatedDays => _parseDays(_estimatedDaysController.text);

  double get _milestonesSum => _milestones.fold<double>(
        0.0,
        (sum, m) => sum + _parseAmount(m.amountController.text),
      );

  int get _milestonesTotalDays => _milestones.fold<int>(
        0,
        (sum, m) => sum + _parseDays(m.daysController.text),
      );

  double get _difference => _totalOffered - _milestonesSum;

  bool get _amountsMatch =>
      _totalOffered > 0 &&
      _milestones.isNotEmpty &&
      _difference.abs() < 0.01;

  void _addMilestone({
    String title = '',
    String description = '',
    String amount = '',
    String days = '',
    bool notify = true,
  }) {
    final draft = _MilestoneDraft(
      title: title,
      description: description,
      amount: amount,
      days: days,
    );
    draft.titleController.addListener(_onValuesChanged);
    draft.descriptionController.addListener(_onValuesChanged);
    draft.amountController.addListener(_onValuesChanged);
    draft.daysController.addListener(_onValuesChanged);

    _milestones.add(draft);
    if (notify && mounted) {
      setState(() {});
    }
  }

  void _removeMilestone(int index) {
    if (_milestones.length <= 1) {
      _showAlertSnackBar(
        'Debes incluir al menos un hito en tu cotización.',
        isError: true,
      );
      return;
    }

    setState(() {
      final removed = _milestones.removeAt(index);
      removed.dispose();
    });
  }

  void _showAlertSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: isError ? AppColors.errorText : AppColors.successText,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  String? _validateBeforeSubmit() {
    if (_totalOffered <= 0) {
      return 'Ingresa un monto global ofertado mayor a \$0 USD.';
    }
    if (_estimatedDays <= 0) {
      return 'Ingresa un tiempo estimado de entrega válido (en días).';
    }
    if (_milestones.isEmpty) {
      return 'Agrega al menos un hito entregable.';
    }
    for (int i = 0; i < _milestones.length; i++) {
      final m = _milestones[i];
      if (m.titleController.text.trim().isEmpty) {
        return 'El hito #${i + 1} necesita un título.';
      }
      if (m.descriptionController.text.trim().isEmpty) {
        return 'El hito #${i + 1} necesita una descripción del entregable.';
      }
      if (_parseAmount(m.amountController.text) <= 0) {
        return 'El hito #${i + 1} debe tener un monto parcial mayor a \$0.';
      }
      if (_parseDays(m.daysController.text) <= 0) {
        return 'El hito #${i + 1} debe indicar su plazo en días.';
      }
    }
    if (!_amountsMatch) {
      return 'La suma de los hitos debe coincidir exactamente con el precio total ofertado.';
    }
    if (_coverLetterController.text.trim().length < 10) {
      return 'Escribe una carta de presentación (mínimo 10 caracteres).';
    }
    return null;
  }

  Future<void> _submitProposal() async {
    FocusScope.of(context).unfocus();

    final validationError = _validateBeforeSubmit();
    if (validationError != null) {
      _showAlertSnackBar(validationError, isError: true);
      return;
    }

    final milestones = _milestones
        .map(
          (m) => ProposalMilestone(
            title: m.titleController.text.trim(),
            description: m.descriptionController.text.trim(),
            amount: _parseAmount(m.amountController.text),
            estimatedDays: _parseDays(m.daysController.text),
          ),
        )
        .toList();

    final request = ProposalRequest(
      projectId: widget.convocatoria.id,
      coverLetter: _coverLetterController.text.trim(),
      totalAmount: _totalOffered,
      estimatedDays: _estimatedDays,
      milestones: milestones,
    );

    setState(() => _isSubmitting = true);

    try {
      final result = await _proposalService.submitProposal(request);

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (result.success) {
        _showAlertSnackBar(result.message, isError: false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ProposalSubmittedScreen(
              convocatoria: widget.convocatoria,
              proposal: request,
              proposalId: result.proposalId,
            ),
          ),
        );
      } else {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.cardSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.errorText),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No se pudo enviar',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              result.message,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textMuted,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'Entendido',
                  style: TextStyle(
                    color: AppColors.wine,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showAlertSnackBar(
        'Ocurrió un error inesperado al enviar la propuesta.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final diffAbs = _difference.abs();
    final isMissing = _difference > 0.005;
    final isExcess = _difference < -0.005;

    final formulaText = _milestones
        .map((m) => _formatUsd(_parseAmount(m.amountController.text)))
        .join(' + ');

    int runningDayStart = 1;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close, size: 20, color: AppColors.textDark),
                        SizedBox(width: 8),
                        Text(
                          'Convocatoria',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.wine,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Prepara tu propuesta',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Define tus entregables, inversión y tiempos.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 18),

                // Tarjeta resumen de convocatoria
                _buildProjectSummaryCard(),
                const SizedBox(height: 24),

                // Sección: Tu propuesta económica
                const Text(
                  'Tu propuesta económica',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildLabeledInput(
                        label: 'Monto global ofertado · USD',
                        controller: _totalAmountController,
                        prefixText: '\$ ',
                        hintText: '2400',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildLabeledInput(
                        label: 'Entrega estimada',
                        controller: _estimatedDaysController,
                        suffixText: 'días',
                        hintText: '30',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Plazos contados desde el inicio del contrato. Los hitos se realizan de forma consecutiva.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.45,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 24),

                // Sección: Hitos y entregables
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Hitos y entregables',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      '${_milestones.length} ${_milestones.length == 1 ? 'hito' : 'hitos'} · $_milestonesTotalDays días',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Lista dinámica de hitos
                ...List.generate(_milestones.length, (index) {
                  final draft = _milestones[index];
                  final days = _parseDays(draft.daysController.text);
                  final startDay = runningDayStart;
                  final endDay = days > 0 ? startDay + days - 1 : startDay;
                  if (days > 0) {
                    runningDayStart = endDay + 1;
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildMilestoneCard(
                      index: index,
                      draft: draft,
                      startDay: startDay,
                      endDay: endDay,
                      days: days,
                    ),
                  );
                }),

                // Botón + Añadir hito
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () => _addMilestone(
                      title: 'Hito ${_milestones.length + 1}',
                      days: '7',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.wine,
                      side: const BorderSide(
                        color: AppColors.dustyRose,
                        width: 1.3,
                      ),
                      backgroundColor: AppColors.cardSurface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    child: const Text(
                      '+ Añadir hito',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Tarjeta Resumen de cotización
                _buildSummaryCard(
                  diffAbs: diffAbs,
                  isMissing: isMissing,
                  isExcess: isExcess,
                ),
                const SizedBox(height: 12),

                // Banner de validación aritmética en tiempo real
                _buildValidationBanner(
                  formulaText: formulaText,
                  diffAbs: diffAbs,
                  isMissing: isMissing,
                  isExcess: isExcess,
                ),
                const SizedBox(height: 24),

                // Sección: Carta de presentación
                const Text(
                  'Carta de presentación',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Para ${widget.convocatoria.company}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _coverLetterFocus.requestFocus(),
                            child: const Text(
                              'Editar carta',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.wine,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _coverLetterController,
                        focusNode: _coverLetterFocus,
                        maxLines: 6,
                        minLines: 4,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: AppColors.textDark,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Hola, equipo de ${widget.convocatoria.company}:\n\nCuéntales tu experiencia, cómo abordarás el proyecto y qué incluye tu propuesta...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted.withValues(alpha: 0.7),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Zona de envío
                const Divider(color: AppColors.cardBorder, height: 1),
                const SizedBox(height: 12),
                Text(
                  _amountsMatch
                      ? 'Al enviar, tu propuesta quedará PENDIENTE y notificaremos al cliente. Aún no es una adjudicación.'
                      : 'Envío inhabilitado hasta corregir la diferencia de ${_formatUsd(diffAbs)} USD.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.45,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: (_amountsMatch && !_isSubmitting)
                        ? _submitProposal
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.wine,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.dustyRose.withValues(alpha: 0.35),
                      disabledForegroundColor:
                          AppColors.textDark.withValues(alpha: 0.45),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Enviar Propuesta',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProjectSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.roseTint,
                child: Text(
                  widget.convocatoria.company.isNotEmpty
                      ? widget.convocatoria.company[0].toUpperCase()
                      : 'C',
                  style: const TextStyle(
                    color: AppColors.wine,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.convocatoria.company,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      widget.convocatoria.timeAgo,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.convocatoria.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildPill('ABIERTO', AppColors.successBg, AppColors.successText),
              _buildPill(
                'Perfil verificado',
                AppColors.roseTint,
                AppColors.wine,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneCard({
    required int index,
    required _MilestoneDraft draft,
    required int startDay,
    required int endDay,
    required int days,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado del hito: Número + Título editable + Botón eliminar
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.roseTint,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.wine,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: draft.titleController,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Título del hito (ej. Diseño y arquitectura)',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.normal,
                      color: AppColors.textMuted,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _removeMilestone(index),
                tooltip: 'Eliminar hito',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Entregable (descripción)
          _buildLabeledInput(
            label: 'Entregable',
            controller: draft.descriptionController,
            hintText: 'Ej. Prototipo y arquitectura técnica',
          ),
          const SizedBox(height: 12),

          // Importe y Plazo de entrega
          Row(
            children: [
              Expanded(
                child: _buildLabeledInput(
                  label: 'Importe · USD',
                  controller: draft.amountController,
                  prefixText: '\$ ',
                  hintText: '600',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLabeledInput(
                  label: 'Plazo de entrega',
                  controller: draft.daysController,
                  suffixText: 'días',
                  hintText: '7',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            days > 0
                ? 'Días $startDay–$endDay desde el inicio del contrato'
                : 'Define los días estimados para este hito',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required double diffAbs,
    required bool isMissing,
    required bool isExcess,
  }) {
    final diffLabel = isMissing
        ? 'Diferencia faltante'
        : isExcess
            ? 'Diferencia excedente'
            : 'Diferencia';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen de cotización',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total ofertado',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              Text(
                '${_formatUsd(_totalOffered)} USD',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Suma de hitos',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              Text(
                '${_formatUsd(_milestonesSum)} USD',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: AppColors.cardBorder, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                diffLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                '${_formatUsd(diffAbs)} USD',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _amountsMatch
                      ? AppColors.successText
                      : AppColors.errorText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildValidationBanner({
    required String formulaText,
    required double diffAbs,
    required bool isMissing,
    required bool isExcess,
  }) {
    if (_amountsMatch) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.successBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              size: 18,
              color: AppColors.successText,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cotización validada',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.successText,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$formulaText = ${_formatUsd(_totalOffered)} USD. La suma de tus hitos coincide con el total ofertado.',
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.45,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final detailMessage = isMissing
        ? 'Los hitos suman ${_formatUsd(_milestonesSum)} USD: faltan ${_formatUsd(diffAbs)} USD para igualar los ${_formatUsd(_totalOffered)} USD ofertados. Ajusta el desglose para habilitar el envío.'
        : isExcess
            ? 'Los hitos suman ${_formatUsd(_milestonesSum)} USD: exceden en ${_formatUsd(diffAbs)} USD los ${_formatUsd(_totalOffered)} USD ofertados. Ajusta el desglose para habilitar el envío.'
            : 'Ingresa un monto global mayor a \$0 USD y desglósalo en tus hitos para habilitar el envío.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: AppColors.errorText,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Los montos no coinciden',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.errorText,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detailMessage,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.45,
                    color: AppColors.errorText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabeledInput({
    required String label,
    required TextEditingController controller,
    String? hintText,
    String? prefixText,
    String? suffixText,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textDark,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            prefixText: prefixText,
            suffixText: suffixText,
            prefixStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textDark,
            ),
            suffixStyle: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
            filled: true,
            fillColor: AppColors.cardSurface,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.wine, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
