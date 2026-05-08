import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_colors.dart';
import 'shared_widgets.dart';
import '../../services/subscription_service.dart';
import '../../providers/auth_provider.dart';

Future<void> showProUpgradeSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProUpgradeSheet(),
  );
}

class _ProUpgradeSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final price = ref.watch(subscriptionPriceProvider) ?? '₹299 / month';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            context.appColors.card,
            context.appColors.bg,
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 12, 24, 32),
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
            SizedBox(height: 24),
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
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Text('👑', style: TextStyle(fontSize: 34)),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Upgrade to Pro',
              style: TextStyle(
                color: context.appColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Unlock unlimited access to all AI features',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.appColors.textSecondary,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 24),
            _BenefitRow(icon: '♾️', text: 'Unlimited ATS checks'),
            SizedBox(height: 10),
            _BenefitRow(icon: '🪄', text: 'Unlimited auto-tailor resumes'),
            SizedBox(height: 10),
            _BenefitRow(icon: '✉️', text: 'Unlimited cover letters'),
            SizedBox(height: 10),
            _BenefitRow(icon: '🤖', text: 'Unlimited AI bullet improvements'),
            SizedBox(height: 10),
            _BenefitRow(icon: '📄', text: 'Ad-free experience'),
            SizedBox(height: 10),
            _BenefitRow(icon: '🎨', text: 'All premium templates'),
            SizedBox(height: 28),
            GradientButton(
              label: 'Subscribe $price',
              gradient: AppColors.goldGradient,
              onPressed: () async {
                final uid = ref.read(authStateProvider).value?.uid;
                if (uid == null) return;
                final success = await ref
                    .read(subscriptionProvider.notifier)
                    .purchasePro(uid: uid);
                if (success && context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🎉 Welcome to Pro!'),
                      backgroundColor: AppColors.scoreGreen,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Maybe later',
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
  final String icon;
  final String text;

  const _BenefitRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(icon, style: TextStyle(fontSize: 16)),
        ),
        SizedBox(width: 10),
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
