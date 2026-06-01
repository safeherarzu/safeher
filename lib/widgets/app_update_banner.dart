import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/app_update_service.dart';
import '../theme/app_theme.dart';

/// Harita / ana ekranın üstünde sabit güncelleme bandı.
class AppUpdateBanner extends StatelessWidget {
  const AppUpdateBanner({
    super.key,
    required this.offer,
    required this.onDismiss,
    required this.onUpdate,
  });

  final AppUpdateOffer offer;
  final VoidCallback onDismiss;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final subtitle = offer.message?.isNotEmpty == true
        ? offer.message!
        : context.tReplace('updateBannerSubtitle', {
            'version': offer.storeVersion,
          });

    return Material(
      elevation: 2,
      color: AppTheme.brandPurple,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.system_update, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('updateBannerTitle'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 12,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onUpdate,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.brandPurple,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 36),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                child: Text(context.t('updateNow')),
              ),
              if (!offer.forceUpdate) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  tooltip: context.t('updateLater'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
