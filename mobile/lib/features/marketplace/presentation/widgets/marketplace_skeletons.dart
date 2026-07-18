import 'package:flutter/material.dart';

import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_shimmer.dart';

class HotelCardSkeletonList extends StatelessWidget {
  const HotelCardSkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Column(
        children: [
          for (var index = 0; index < 4; index += 1) ...[
            const _HotelCardSkeleton(),
            if (index < 3) const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

class DetailSkeleton extends StatelessWidget {
  const DetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerBlock(
            width: double.infinity,
            height: 220,
            borderRadius: AppRadii.lg,
          ),
          const SizedBox(height: AppSpacing.xl),
          const ShimmerBlock(width: 220, height: 28),
          const SizedBox(height: AppSpacing.sm),
          const ShimmerBlock(width: 320, height: 16),
          const SizedBox(height: AppSpacing.xxl),
          for (var index = 0; index < 3; index += 1) ...[
            const ShimmerBlock(
              width: double.infinity,
              height: 132,
              borderRadius: AppRadii.md,
            ),
            if (index < 2) const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _HotelCardSkeleton extends StatelessWidget {
  const _HotelCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            ShimmerBlock(
              width: 92,
              height: 104,
              borderRadius: AppRadii.md,
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBlock(width: 180, height: 20),
                  SizedBox(height: AppSpacing.sm),
                  ShimmerBlock(width: double.infinity, height: 14),
                  SizedBox(height: AppSpacing.xs),
                  ShimmerBlock(width: 240, height: 14),
                  SizedBox(height: AppSpacing.lg),
                  ShimmerBlock(width: 140, height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
