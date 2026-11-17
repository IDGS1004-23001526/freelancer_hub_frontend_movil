import 'package:flutter/material.dart';
import '../theme/app_colors.dart'; // O la ruta correcta donde tengas AppColors

class AdvancedFiltersModal extends StatefulWidget {
  final String? initialCategory;
  final RangeValues initialBudget;
  final String? initialPaymentType;
  final Set<String> selectedSkills;
  final List<String> allSkills;

  const AdvancedFiltersModal({
    Key? key,
    this.initialCategory,
    required this.initialBudget,
    this.initialPaymentType,
    required this.selectedSkills,
    required this.allSkills,
  }) : super(key: key);

  @override
  State<AdvancedFiltersModal> createState() => _AdvancedFiltersModalState();
}

class _AdvancedFiltersModalState extends State<AdvancedFiltersModal> {
  late String? _selectedCategory;
  late RangeValues _budgetRange;
  late String? _selectedPaymentType;

  final List<String> _categories = [
    'Desarrollo móvil',
    'Desarrollo web',
    'Diseño y creatividad',
    'Datos e IA'
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _budgetRange = widget.initialBudget;
    _selectedPaymentType = widget.initialPaymentType;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filtros avanzados',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Text(
              'Afina tu búsqueda de convocatorias.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),

            // Categorías
            const Text('Categorías',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Selecciona el área en la que quieres trabajar.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary),
                  onSelected: (selected) {
                    setState(() => _selectedCategory = selected ? cat : null);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Rango de presupuesto
            const Text('Rango de presupuesto',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Presupuesto total del proyecto en USD.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('\$${_budgetRange.start.toStringAsFixed(0)} USD',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('\$${_budgetRange.end.toStringAsFixed(0)} USD',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            RangeSlider(
              values: _budgetRange,
              min: 500,
              max: 8000,
              divisions: 15,
              activeColor: AppColors.primary,
              inactiveColor: AppColors.border,
              onChanged: (values) => setState(() => _budgetRange = values),
            ),
            const SizedBox(height: 20),

            // Tipo de pago
            const Text('Tipo de pago',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: ['Precio fijo', 'Por hitos (Escrow)'].map((type) {
                final isSelected = _selectedPaymentType == type;
                return ChoiceChip(
                  label: Text(type),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary),
                  onSelected: (selected) {
                    setState(
                        () => _selectedPaymentType = selected ? type : null);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 30),

            // Botones inferiores
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedCategory = null;
                      _selectedPaymentType = null;
                      _budgetRange = const RangeValues(500, 5000);
                    });
                  },
                  child: const Text('Restablecer',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, {
                        'category': _selectedCategory,
                        'budget': _budgetRange,
                        'paymentType': _selectedPaymentType,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Aplicar filtros',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
