import 'package:flutter/material.dart';
import '../../models/convocatoria.dart';
import '../../theme/app_colors.dart';
import '../../widgets/advanced_filters_modal.dart';
import '../chat/conversations_screen.dart';
import '../profile/profile_screen.dart';

class ExplorarScreen extends StatefulWidget {
  const ExplorarScreen({super.key});

  @override
  State<ExplorarScreen> createState() => _ExplorarScreenState();
}

class _ExplorarScreenState extends State<ExplorarScreen> {
  int _currentIndex = 0;
  String _searchQuery = '';

  final Set<String> _selectedSkills = {};

  RangeValues _budgetRange = const RangeValues(500, 5000);
  String? _selectedCategory;
  String? _selectedPaymentType;
  bool _advancedFiltersActive = false;

  final List<String> _allSkills = [
    'Flutter',
    '.NET Core',
    'React',
    'SQL Server',
    'UI/UX',
    'Java',
  ];

  final List<Convocatoria> _convocatorias = [
    Convocatoria(
      id: '1',
      title: 'E-commerce móvil con pasarela de pagos',
      company: 'Nexo Commerce',
      timeAgo: 'Hace 2 h · Convocatoria activa',
      category: 'Desarrollo móvil',
      tags: ['Flutter', '.NET Core', 'SQL Server'],
      budget: 2400,
      remainingDays: 30,
      paymentType: 'Precio fijo',
      remoteType: 'Remoto',
    ),
    Convocatoria(
      id: '2',
      title: 'Diseño UX/UI para una app de bienestar',
      company: 'Estudio Bruma',
      timeAgo: 'Hace 4 h · Convocatoria activa',
      category: 'Diseño y creatividad',
      tags: ['UI/UX', 'Figma', 'Prototipado'],
      budget: 1200,
      remainingDays: 21,
      paymentType: 'Precio fijo',
      remoteType: 'Remoto',
    ),
    Convocatoria(
      id: '3',
      title: 'App de seguimiento de entregas en tiempo real',
      company: 'Ruta Logística',
      timeAgo: 'Hace 6 h · Convocatoria activa',
      category: 'Desarrollo móvil',
      tags: ['Flutter', '.NET Core', 'Azure'],
      budget: 3200,
      remainingDays: 45,
      paymentType: 'Precio fijo',
      remoteType: 'Remoto',
    ),
  ];

  List<Convocatoria> get _filteredConvocatorias {
    return _convocatorias.where((item) {
      final matchesSearch = _searchQuery.isEmpty ||
          item.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.company.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.category.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesSkills = _selectedSkills.isEmpty ||
          _selectedSkills.every((skill) => item.tags.contains(skill));

      final matchesCategory = _selectedCategory == null ||
          _selectedCategory!.isEmpty ||
          item.category == _selectedCategory;

      final matchesBudget =
          item.budget >= _budgetRange.start && item.budget <= _budgetRange.end;

      final matchesPayment = _selectedPaymentType == null ||
          _selectedPaymentType!.isEmpty ||
          item.paymentType == _selectedPaymentType;

      return matchesSearch &&
          matchesSkills &&
          matchesCategory &&
          matchesBudget &&
          matchesPayment;
    }).toList();
  }

  void _resetFilters() {
    setState(() {
      _selectedSkills.clear();
      _searchQuery = '';
      _selectedCategory = null;
      _selectedPaymentType = null;
      _budgetRange = const RangeValues(500, 5000);
      _advancedFiltersActive = false;
    });
  }

  void _openAdvancedFilters() async {
    final Map<String, dynamic>? result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AdvancedFiltersModal(
        initialCategory: _selectedCategory,
        initialBudget: _budgetRange,
        initialPaymentType: _selectedPaymentType,
        selectedSkills: _selectedSkills,
        allSkills: _allSkills,
      ),
    );

    if (result != null) {
      setState(() {
        _selectedCategory = result['category'];
        _budgetRange = result['budget'];
        _selectedPaymentType = result['paymentType'];
        _advancedFiltersActive = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredConvocatorias;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Explorar',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Tu próximo proyecto empieza aquí.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: const Text(
                      'L',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Barra de Búsqueda y Botón de Filtros
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TextField(
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                        decoration: const InputDecoration(
                          hintText: 'Buscar convocatorias...',
                          prefixIcon: Icon(Icons.search,
                              color: AppColors.textSecondary),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Stack(
                    children: [
                      IconButton(
                        onPressed: _openAdvancedFilters,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          padding: const EdgeInsets.all(12),
                        ),
                        icon: const Icon(Icons.tune,
                            color: AppColors.textPrimary),
                      ),
                      if (_advancedFiltersActive)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Text(
                              '5',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Chips horizontales de habilidades
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: const Text('Todos'),
                      selected: _selectedSkills.isEmpty,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.chipBackground,
                      labelStyle: TextStyle(
                        color: _selectedSkills.isEmpty
                            ? Colors.white
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedSkills.clear());
                      },
                    ),
                  ),
                  ..._allSkills.map((skill) {
                    final isSelected = _selectedSkills.contains(skill);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text(skill),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.chipBackground,
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          color:
                              isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
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
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Subtítulo de estado de filtros
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                children: [
                  Icon(Icons.bolt, size: 16, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text(
                    'Toca una habilidad y descubre coincidencias al instante.',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),

            // Lista de resultados o Estado Vacío
            Expanded(
              child: filteredList.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${filteredList.length} convocatorias activas',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Text(
                              'Recientes ▾',
                              style: TextStyle(
                                  color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...filteredList
                            .map((item) => _buildConvocatoriaCard(item)),
                      ],
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ConversationsScreen()),
            );
            return;
          }
          if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
            return;
          }
          setState(() => _currentIndex = index);
        },
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explorar'),
          BottomNavigationBarItem(
              icon: Icon(Icons.work_outline), label: 'Postulaciones'),
          BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), label: 'Perfil'),
        ],
      ),
    );
  }

  Widget _buildConvocatoriaCard(Convocatoria item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Text(
                      item.company[0],
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.company,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        item.timeAgo,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              const Icon(Icons.bookmark_border,
                  size: 20, color: AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '\$${item.budget.toStringAsFixed(0)} USD',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.access_time,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '${item.remainingDays} días',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6.0,
            runSpacing: 4.0,
            children: item.tags.map((tag) {
              return Chip(
                label: Text(tag, style: const TextStyle(fontSize: 11)),
                backgroundColor: AppColors.chipBackground,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            '${item.category} · ${item.remoteType} · ${item.paymentType}',
            style:
                const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No encontramos convocatorias',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'No hay proyectos activos con todas estas habilidades y este presupuesto.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _resetFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Restablecer filtros',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Se quitarán todos los filtros para volver a ver las convocatorias activas.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
