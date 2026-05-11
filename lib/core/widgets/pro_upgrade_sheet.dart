import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/subscription_service.dart';
import '../constants/app_colors.dart';
import 'shared_widgets.dart';

Future<void> showProUpgradeSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ProUpgradeSheet(),
  );
}

class _ProUpgradeSheet extends ConsumerWidget {
  const _ProUpgradeSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final price = ref.watch(subscriptionPriceProvider);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [context.appColors.card, context.appColors.bg],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.appColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentGold.withValues(alpha: 0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.workspace_premium, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Pro Coming Soon',
              style: TextStyle(
                color: context.appColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Paid upgrades are disabled until Google Play Billing is fully configured.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.appColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            const _BenefitRow(icon: Icons.analytics_outlined, text: 'More ATS checks'),
            const SizedBox(height: 10),
            const _BenefitRow(icon: Icons.auto_fix_high, text: 'More AI tailoring'),
            const SizedBox(height: 10),
            const _BenefitRow(icon: Icons.description_outlined, text: 'More cover letters'),
            const SizedBox(height: 10),
            const _BenefitRow(icon: Icons.block, text: 'No fake purchase flow'),
            const SizedBox(height: 28),
            GradientButton(
              label: price == null ? 'Billing Not Available' : 'Subscribe $price',
              gradient: AppColors.goldGradient,
              onPressed: null,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: TextStyle(
                  color: context.appColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BenefitRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 28,
          child: Icon(icon, size: 18, color: AppColors.accentGold),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
            color: context.appColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
