import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/utils/currency_formatter.dart';
import 'package:deskflow/core/widgets/surface_card.dart';
import 'package:deskflow/features/orders/domain/customer.dart';
import 'package:deskflow/features/orders/domain/order_template.dart';
import 'package:deskflow/features/products/domain/product.dart';

class OrderQuickSourcesPanel extends StatelessWidget {
  const OrderQuickSourcesPanel({
    super.key,
    required this.templatesAsync,
    required this.recentCustomersAsync,
    required this.recentProductsAsync,
    required this.onTemplateTap,
    required this.onCustomerTap,
    required this.onProductTap,
    this.headerAction,
  });

  final AsyncValue<List<OrderTemplate>> templatesAsync;
  final AsyncValue<List<Customer>> recentCustomersAsync;
  final AsyncValue<List<Product>> recentProductsAsync;
  final ValueChanged<OrderTemplate> onTemplateTap;
  final ValueChanged<Customer> onCustomerTap;
  final ValueChanged<Product> onProductTap;
  final Widget? headerAction;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      key: const Key('quick-sources-panel'),
      variant: SurfaceCardVariant.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Быстрые источники', style: DeskflowTypography.h3),
                    SizedBox(height: DeskflowSpacing.xs),
                    Text(
                      'Шаблоны, недавние клиенты и товары',
                      style: DeskflowTypography.meta,
                    ),
                  ],
                ),
              ),
              if (headerAction != null) ...[
                const SizedBox(width: DeskflowSpacing.md),
                headerAction!,
              ],
            ],
          ),
          const SizedBox(height: DeskflowSpacing.lg),
          _QuickSourceSection<OrderTemplate>(
            sectionKeyPrefix: 'quick-source-template',
            title: 'Шаблоны',
            emptyText: 'Шаблонов пока нет',
            icon: Icons.copy_all_rounded,
            itemsAsync: templatesAsync,
            labelBuilder: (template) => template.name,
            actionLabel: 'Применить',
            onTap: onTemplateTap,
          ),
          const SizedBox(height: DeskflowSpacing.lg),
          _QuickSourceSection<Customer>(
            sectionKeyPrefix: 'quick-source-customer',
            title: 'Последние клиенты',
            emptyText: 'Недавних клиентов пока нет',
            icon: Icons.person_outline_rounded,
            itemsAsync: recentCustomersAsync,
            labelBuilder: (customer) => customer.name,
            subtitleBuilder: (customer) => customer.phone,
            actionLabel: 'Выбрать',
            onTap: onCustomerTap,
          ),
          const SizedBox(height: DeskflowSpacing.lg),
          _QuickSourceSection<Product>(
            sectionKeyPrefix: 'quick-source-product',
            title: 'Последние товары',
            emptyText: 'Недавних товаров пока нет',
            icon: Icons.inventory_2_outlined,
            itemsAsync: recentProductsAsync,
            labelBuilder: (product) => product.name,
            subtitleBuilder: (product) =>
                CurrencyFormatter.formatCompact(product.price),
            actionLabel: 'Добавить',
            onTap: onProductTap,
          ),
        ],
      ),
    );
  }
}

class _QuickSourceSection<T> extends StatelessWidget {
  const _QuickSourceSection({
    required this.sectionKeyPrefix,
    required this.title,
    required this.emptyText,
    required this.icon,
    required this.itemsAsync,
    required this.labelBuilder,
    required this.onTap,
    required this.actionLabel,
    this.subtitleBuilder,
  });

  final String sectionKeyPrefix;
  final String title;
  final String emptyText;
  final IconData icon;
  final AsyncValue<List<T>> itemsAsync;
  final String Function(T item) labelBuilder;
  final String? Function(T item)? subtitleBuilder;
  final ValueChanged<T> onTap;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: DeskflowTypography.bodySmall.copyWith(
            color: DeskflowColors.textSecondary,
          ),
        ),
        const SizedBox(height: DeskflowSpacing.sm),
        itemsAsync.when(
          skipLoadingOnRefresh: true,
          skipLoadingOnReload: true,
          data: (items) {
            if (items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: DeskflowSpacing.xs),
                child: Text(
                  emptyText,
                  style: DeskflowTypography.bodySmall.copyWith(
                    color: DeskflowColors.textTertiary,
                  ),
                ),
              );
            }

            final visibleItems = items.take(3).toList();
            return Column(
              children: [
                for (var i = 0; i < visibleItems.length; i++) ...[
                  _QuickSourceRow(
                    key: Key('$sectionKeyPrefix-row-$i'),
                    icon: icon,
                    label: labelBuilder(visibleItems[i]),
                    subtitle: subtitleBuilder?.call(visibleItems[i]),
                    actionLabel: actionLabel,
                    onTap: () => onTap(visibleItems[i]),
                  ),
                  if (i != visibleItems.length - 1)
                    const SizedBox(height: DeskflowSpacing.sm),
                ],
              ],
            );
          },
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (error, stackTrace) => Text(
            'Не удалось загрузить',
            style: DeskflowTypography.bodySmall.copyWith(
              color: DeskflowColors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickSourceRow extends StatelessWidget {
  const _QuickSourceRow({
    super.key,
    required this.icon,
    required this.label,
    required this.actionLabel,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      variant: SurfaceCardVariant.elevated,
      borderRadius: DeskflowRadius.workTile,
      padding: const EdgeInsets.symmetric(
        horizontal: DeskflowSpacing.md,
        vertical: DeskflowSpacing.md,
      ),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: DeskflowColors.workSurface,
              borderRadius: BorderRadius.circular(DeskflowRadius.sm),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 18,
              color: DeskflowColors.textSecondary,
            ),
          ),
          const SizedBox(width: DeskflowSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: DeskflowTypography.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: DeskflowSpacing.xs),
                  Text(
                    subtitle!,
                    style: DeskflowTypography.meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: DeskflowSpacing.md),
          Text(
            actionLabel,
            style: DeskflowTypography.caption.copyWith(
              color: DeskflowColors.primarySolid,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
