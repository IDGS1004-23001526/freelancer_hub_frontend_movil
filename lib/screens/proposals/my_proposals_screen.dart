import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/proposal.dart';
import '../../services/proposal_service.dart';
import '../../theme/app_colors.dart';

class MyProposalsScreen extends StatefulWidget {
  const MyProposalsScreen({super.key});

  @override
  State<MyProposalsScreen> createState() => _MyProposalsScreenState();
}

class _MyProposalsScreenState extends State<MyProposalsScreen> {
  final ProposalService _service = ProposalService();
  bool _loading = true;
  List<SubmittedProposal> _items = [];
  StreamSubscription<void>? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = ProposalService.onProposalsChanged.listen((_) {
      if (mounted) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }
    final res = await _service.getMyProposals();
    if (mounted) {
      setState(() {
        _items = res;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cardSurface,
        elevation: 0,
        title: const Text(
          'Mis Postulaciones',
          style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.wine),
            onPressed: () => _load(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.wine))
          : RefreshIndicator(
              color: AppColors.wine,
              onRefresh: () => _load(silent: true),
              child: _items.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(
                          child: Text(
                            'Aún no tienes postulaciones registradas.',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
        itemBuilder: (context, i) {
          final p = _items[i];
          final isWon = p.status == 'ADJUDICADA';
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isWon
                            ? AppColors.successBg
                            : AppColors.roseTint,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        p.status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isWon
                              ? AppColors.successText
                              : AppColors.wine,
                        ),
                      ),
                    ),
                    Text(
                      '\$${p.totalAmount.toStringAsFixed(0)} USD',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.wine,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  p.projectTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  '${p.companyName} · ${p.estimatedDays} días · ${p.milestones.length} hitos',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          );
        },
      ),
    ),
    );
  }
}