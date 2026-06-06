import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/utils/currency_formatter.dart';
import 'package:deskflow/core/widgets/error_state_widget.dart';
import 'package:deskflow/core/widgets/skeleton_loader.dart';
import 'package:deskflow/core/widgets/status_pill_badge.dart';
import 'package:deskflow/core/widgets/surface_card.dart';
import 'package:deskflow/core/widgets/work_list_tile.dart';
import 'package:deskflow/core/widgets/work_primary_action_bar.dart';
import 'package:deskflow/core/widgets/work_screen_scaffold.dart';
import 'package:deskflow/core/widgets/work_section_header.dart';
import 'package:deskflow/features/orders/domain/audit_event.dart';
import 'package:deskflow/features/orders/domain/order.dart';
import 'package:deskflow/features/orders/domain/order_providers.dart';
import 'package:deskflow/features/orders/presentation/status_change_sheet.dart';
import 'package:deskflow/features/chat/domain/chat_providers.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    return WorkScreenScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: orderAsync.whenOrNull(
          data: (order) => Text(order.formattedNumber),
        ),
        actions: [
          if (orderAsync.hasValue)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              color: DeskflowColors.glassSurfaceElevated,
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Редактировать'),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  context.go('/orders/$orderId/edit');
                }
              },
            ),
        ],
      ),
      body: orderAsync.when(        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const _LoadingSkeleton(),
        error: (error, _) => ErrorStateWidget(
          message: error.toString(),
          onRetry: () => ref.invalidate(orderDetailProvider(orderId)),
        ),
        data: (order) => _OrderDetailBody(
          order: order,
          orderId: orderId,
        ),
      ),
      bottomActionBar: orderAsync.whenOrNull(
        data: (order) => _BottomActionBar(order: order, orderId: orderId),
      ),
    );
  }
}

class _OrderDetailBody extends ConsumerWidget {
  const _OrderDetailBody({
    required this.order,
    required this.orderId,
  });

  final Order order;
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: DeskflowColors.primarySolid,
      onRefresh: () async {
        ref.invalidate(orderDetailProvider(orderId));
      },
      child: ListView(
        padding: const EdgeInsets.all(DeskflowSpacing.lg),
        children: [
          _HeaderSection(order: order),
          const SizedBox(height: DeskflowSpacing.lg),

          if (order.customerName != null) ...[
            const _SectionTitle(title: 'Клиент'),
            SurfaceCard(
              child: Row(
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    size: 20,
                    color: DeskflowColors.textSecondary,
                  ),
                  const SizedBox(width: DeskflowSpacing.sm),
                  Expanded(
                    child: Text(
                      order.customerName!,
                      style: DeskflowTypography.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DeskflowSpacing.lg),
          ],

          _SectionTitle(title: 'Товары (${order.items.length})'),
          if (order.items.isEmpty)
            const SurfaceCard(
              child: Center(
                child: Text('Нет товаров', style: DeskflowTypography.bodySmall),
              ),
            )
          else
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: order.items
                    .map(
                      (item) => WorkListTile(
                        key: Key('order-item-row-${item.id}'),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: DeskflowColors.workSurfaceElevated,
                            borderRadius: BorderRadius.circular(DeskflowRadius.sm),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${item.quantity}',
                            style: DeskflowTypography.caption.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        title: Text(item.productName),
                        subtitle: Text(
                          '${item.quantity} × ${CurrencyFormatter.formatCompact(item.unitPrice)}',
                        ),
                        trailing: Text(
                          CurrencyFormatter.formatCompact(item.subtotal),
                          style: DeskflowTypography.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        showDivider: order.items.last != item,
                      ),
                    )
                    .toList(),
              ),
            ),

          const SizedBox(height: DeskflowSpacing.lg),

          const _SectionTitle(title: 'Стоимость'),
          SurfaceCard(
            child: Column(
              children: [
                _CostRow(
                  label: 'Товары',
                  value: CurrencyFormatter.formatCompact(order.itemsTotal),
                ),
                if (order.deliveryCost > 0) ...[
                  const SizedBox(height: DeskflowSpacing.sm),
                  _CostRow(
                    label: 'Доставка',
                    value: CurrencyFormatter.formatCompact(order.deliveryCost),
                  ),
                ],
                const SizedBox(height: DeskflowSpacing.sm),
                const Divider(color: DeskflowColors.workDivider),
                const SizedBox(height: DeskflowSpacing.sm),
                _CostRow(
                  label: 'Итого',
                  value: CurrencyFormatter.formatCompact(order.grandTotal),
                  bold: true,
                ),
              ],
            ),
          ),

          if (order.notes != null && order.notes!.isNotEmpty) ...[
            const SizedBox(height: DeskflowSpacing.lg),
            const _SectionTitle(title: 'Заметки'),
            SurfaceCard(
              child: Text(order.notes!, style: DeskflowTypography.body),
            ),
          ],

          const SizedBox(height: DeskflowSpacing.lg),

          _ChatPreviewSection(orderId: orderId),

          const SizedBox(height: DeskflowSpacing.lg),

          _AuditLogSection(orderId: orderId),

          const SizedBox(height: DeskflowSpacing.xxl),
        ],
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      key: const Key('order-detail-header'),
      variant: SurfaceCardVariant.elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compactHeader = constraints.maxWidth < 420;

              if (compactHeader) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.formattedNumber,
                      style: DeskflowTypography.h1,
                    ),
                    if (order.status != null) ...[
                      const SizedBox(height: DeskflowSpacing.sm),
                      StatusPillBadge(
                        label: order.status!.name,
                        color: order.status!.materialColor,
                      ),
                    ],
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      order.formattedNumber,
                      style: DeskflowTypography.h1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (order.status != null) ...[
                    const SizedBox(width: DeskflowSpacing.md),
                    StatusPillBadge(
                      label: order.status!.name,
                      color: order.status!.materialColor,
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: DeskflowSpacing.sm),
          Text(_formatDate(order.createdAt), style: DeskflowTypography.bodySmall),
          const SizedBox(height: DeskflowSpacing.md),
          Wrap(
            spacing: DeskflowSpacing.lg,
            runSpacing: DeskflowSpacing.sm,
            children: [
              _HeaderMeta(
                label: 'Клиент',
                value: order.customerName ?? 'Без клиента',
              ),
              _HeaderMeta(
                label: 'Сумма',
                value: CurrencyFormatter.formatCompact(order.grandTotal),
              ),
              _HeaderMeta(
                label: 'Позиций',
                value: '${order.items.length}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      '', 'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}, '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _ChatPreviewSection extends ConsumerWidget {
  const _ChatPreviewSection({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewAsync = ref.watch(chatPreviewProvider(orderId));
    final countAsync = ref.watch(chatMessageCountProvider(orderId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Чат'),
        GestureDetector(
          onTap: () => context.push('/orders/$orderId/chat'),
          child: SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                previewAsync.when(                  skipLoadingOnRefresh: true,
                  skipLoadingOnReload: true,
                  loading: () => SkeletonLoader.box(height: 60),
                  error: (e, _) => Text('Ошибка: $e',
                      style: DeskflowTypography.bodySmall),
                  data: (messages) {
                    if (messages.isEmpty) {
                      return Row(
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded,
                              size: 20,
                              color: DeskflowColors.textTertiary),
                          const SizedBox(width: DeskflowSpacing.sm),
                          Text(
                            'Начните обсуждение заказа',
                            style: DeskflowTypography.bodySmall,
                          ),
                        ],
                      );
                    }
                    return Column(
                      children: messages.map((msg) {
                        final name = msg.senderName ?? 'Участник';
                        final text = msg.text ?? '📎 Вложение';
                        return Padding(
                          padding: const EdgeInsets.only(
                              bottom: DeskflowSpacing.xs),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$name: ',
                                style:
                                    DeskflowTypography.bodySmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  text,
                                  style: DeskflowTypography.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: DeskflowSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    countAsync.when(                      skipLoadingOnRefresh: true,
                      skipLoadingOnReload: true,
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (count) => Text(
                        'Открыть чат ($count)',
                        style: DeskflowTypography.bodySmall.copyWith(
                          color: DeskflowColors.primarySolid,
                        ),
                      ),
                    ),
                    const SizedBox(width: DeskflowSpacing.xs),
                    const Icon(Icons.chevron_right_rounded,
                        size: 18,
                        color: DeskflowColors.primarySolid),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AuditLogSection extends ConsumerWidget {
  const _AuditLogSection({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditAsync = ref.watch(_auditLogProvider(orderId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'История'),
        auditAsync.when(          skipLoadingOnRefresh: true,
          skipLoadingOnReload: true,
          loading: () => SkeletonLoader.box(height: 80),
          error: (e, _) => Text('Ошибка: $e',
              style: DeskflowTypography.bodySmall),
          data: (events) {
            if (events.isEmpty) {
              return const SurfaceCard(
                child: Text(
                  'Нет записей',
                  style: DeskflowTypography.bodySmall,
                ),
              );
            }
            return SurfaceCard(
              padding: const EdgeInsets.symmetric(
                horizontal: DeskflowSpacing.md,
                vertical: DeskflowSpacing.sm,
              ),
              child: Column(
                children: events
                    .take(10)
                    .map((event) => _AuditEventRow(event: event))
                    .toList(),
              ),
            );
          },
        ),
      ],
    );
  }
}

final _auditLogProvider =
    FutureProvider.family<List<AuditEvent>, String>((ref, orderId) {
  return ref.read(orderRepositoryProvider).getOrderAuditLog(orderId);
});

class _AuditEventRow extends StatelessWidget {
  const _AuditEventRow({required this.event});

  final AuditEvent event;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(vertical: DeskflowSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: DeskflowColors.textSecondary,
            ),
          ),
          const SizedBox(width: DeskflowSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.actionLabel,
                    style: DeskflowTypography.body),
                Row(
                  children: [
                    if (event.userName != null)
                      Text('${event.userName} · ',
                          style: DeskflowTypography.caption),
                    Text(
                      _timeAgo(event.createdAt),
                      style: DeskflowTypography.caption,
                    ),
                  ],
                ),
                if (event.action == 'status_changed' &&
                    event.newValue != null)
                  Padding(
                    padding:
                        const EdgeInsets.only(top: DeskflowSpacing.xs),
                    child: Text(
                      '→ ${event.newValue!['status'] ?? ''}',
                      style: DeskflowTypography.bodySmall.copyWith(
                        color: DeskflowColors.primarySolid,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
    if (diff.inHours < 24) return '${diff.inHours} ч назад';
    if (diff.inDays < 30) return '${diff.inDays} д назад';
    return '${dt.day}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }
}

class _BottomActionBar extends ConsumerWidget {
  const _BottomActionBar({required this.order, required this.orderId});

  final Order order;
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFinal = order.status?.isFinal ?? false;

    return WorkPrimaryActionBar(
      key: const Key('order-detail-action-bar'),
      summary: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Итого',
            style: DeskflowTypography.bodySmall.copyWith(
              color: DeskflowColors.workMutedText,
            ),
          ),
          const SizedBox(height: DeskflowSpacing.xs),
          Text(
            CurrencyFormatter.formatCompact(order.grandTotal),
            style: DeskflowTypography.h3,
          ),
        ],
      ),
      label: isFinal ? 'Завершён' : 'Сменить статус',
      onPressed: isFinal ? null : () => _showStatusSheet(context, ref),
    );
  }

  void _showStatusSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatusChangeSheet(
        orderId: orderId,
        currentStatusId: order.statusId,
      ),
    );
  }
}

class _CostRow extends StatelessWidget {
  const _CostRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? DeskflowTypography.body.copyWith(fontWeight: FontWeight.w700)
        : DeskflowTypography.body;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: style),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return WorkSectionHeader(title: title);
  }
}

class _HeaderMeta extends StatelessWidget {
  const _HeaderMeta({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: DeskflowTypography.caption.copyWith(
            color: DeskflowColors.workMutedText,
          ),
        ),
        const SizedBox(height: 2),
        Text(value, style: DeskflowTypography.body),
      ],
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonGroup(
      child: SkeletonLoader(
        child: Padding(
          padding: const EdgeInsets.all(DeskflowSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonLoader.box(height: 80),
              const SizedBox(height: DeskflowSpacing.lg),
              SkeletonLoader.box(height: 50),
              const SizedBox(height: DeskflowSpacing.lg),
              SkeletonLoader.box(height: 120),
              const SizedBox(height: DeskflowSpacing.lg),
              SkeletonLoader.box(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}
