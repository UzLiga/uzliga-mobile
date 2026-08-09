import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/offline_cache.dart';
import '../../core/theme/app_theme.dart';

class PcNetworkImage extends StatelessWidget {
  const PcNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  final String url;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  /// Decode size in physical pixels — keeps scroll smooth.
  final int? memCacheWidth;
  final int? memCacheHeight;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final w = memCacheWidth ?? (360 * dpr).round();
    final child = url.isEmpty
        ? Container(
            color: AppColors.surface2,
            alignment: Alignment.center,
            child: const Icon(Icons.stadium_outlined, color: AppColors.faint),
          )
        : CachedNetworkImage(
            imageUrl: url,
            fit: fit,
            memCacheWidth: w,
            memCacheHeight: memCacheHeight,
            fadeInDuration: const Duration(milliseconds: 80),
            fadeOutDuration: Duration.zero,
            placeholder: (_, __) => Container(color: AppColors.surface2),
            errorWidget: (_, __, ___) => Container(
              color: AppColors.surface2,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined,
                  color: AppColors.faint),
            ),
          );

    if (borderRadius == null) return child;
    return ClipRRect(borderRadius: borderRadius!, child: child);
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF166534), Color(0xFF052E16)],
                ),
                border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: Icon(icon, size: 40, color: AppColors.gold),
            ),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, height: 1.4),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 18),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    // Skeleton — "Yuklanmoqda" matnsiz, silliq shimmer-like blocks
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _bone(height: 120, radius: 18),
        const SizedBox(height: 12),
        _bone(height: 18, width: 160),
        const SizedBox(height: 10),
        _bone(height: 72, radius: 14),
        const SizedBox(height: 10),
        _bone(height: 72, radius: 14),
        const SizedBox(height: 10),
        _bone(height: 72, radius: 14),
      ],
    );
  }

  Widget _bone({double height = 16, double? width, double radius = 10}) {
    return Container(
      height: height,
      width: width ?? double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.edge.withValues(alpha: 0.5)),
      ),
    );
  }
}

/// Offline banner — online bo‘lsa hech narsa ko‘rsatmaydi.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(connectivityProvider).online;
    if (online) return const SizedBox.shrink();
    return Material(
      color: const Color(0xFF7C2D12),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: const [
              Icon(Icons.cloud_off, size: 16, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Offline · oxirgi saqlangan ma’lumot',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 40),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onRetry, child: const Text('Qayta urinish')),
            ],
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        const Spacer(),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}
