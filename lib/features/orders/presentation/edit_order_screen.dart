import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:deskflow/core/errors/deskflow_exception.dart';
import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/utils/currency_formatter.dart';
import 'package:deskflow/core/utils/text_input_formatters.dart';
import 'package:deskflow/core/widgets/error_state_widget.dart';
import 'package:deskflow/core/widgets/glass_card.dart';
import 'package:deskflow/core/widgets/glass_text_field.dart';
import 'package:deskflow/core/widgets/skeleton_loader.dart';
import 'package:deskflow/core/widgets/work_primary_action_bar.dart';
import 'package:deskflow/core/widgets/work_screen_scaffold.dart';
import 'package:deskflow/features/orders/domain/customer.dart';
import 'package:deskflow/features/orders/domain/order.dart';
import 'package:deskflow/features/orders/domain/order_composition.dart';
import 'package:deskflow/features/orders/domain/order_notifier.dart';
import 'package:deskflow/features/orders/domain/order_providers.dart';
import 'package:deskflow/features/orders/domain/order_template.dart';
import 'package:deskflow/features/orders/presentation/order_quick_sources_panel.dart';
import 'package:deskflow/features/products/domain/product.dart';

class EditOrderScreen extends HookConsumerWidget {
  final String orderId;

  const EditOrderScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    return orderAsync.when(      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      data: (order) => _EditOrderForm(order: order),
      loading: () => Scaffold(
        backgroundColor: DeskflowColors.background,
        appBar: AppBar(title: const Text('Загрузка...')),
        body: SkeletonLoader(
          child: ListView(
            padding: const EdgeInsets.all(DeskflowSpacing.lg),
            children: [
              SkeletonLoader.box(height: 120),
              const SizedBox(height: DeskflowSpacing.lg),
              SkeletonLoader.box(height: 200),
            ],
          ),
        ),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: DeskflowColors.background,
        appBar: AppBar(title: const Text('Ошибка')),
        body: ErrorStateWidget(
          message: error.toString(),
          onRetry: () => ref.invalidate(orderDetailProvider(orderId)),
        ),
      ),
    );
  }
}

class _EditOrderForm extends HookConsumerWidget {
  final Order order;

  const _EditOrderForm({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesController = useTextEditingController(text: order.notes ?? '');
    final deliveryCostController = useTextEditingController(
      text: order.deliveryCost.toStringAsFixed(2),
    );
    final selectedCustomer = useState<Customer?>(
      order.customerId == null
          ? null
          : Customer(
              id: order.customerId!,
              organizationId: order.organizationId,
              name: order.customerName ?? 'Клиент',
              createdAt: order.createdAt,
            ),
    );
    final orderState = ref.watch(orderNotifierProvider);
    final isLoading = orderState.isLoading;
    final templatesAsync = ref.watch(orderTemplatesProvider);
    final recentCustomersAsync = ref.watch(recentOrderCustomersProvider);
    final recentProductsAsync = ref.watch(recentOrderProductsProvider);
    final bp = DeskflowBreakpoints.of(context);

    ref.listen<AsyncValue<void>>(orderNotifierProvider, (_, next) {
      if (next.hasError) {
        final error = next.error;
        final message = error is DeskflowException
            ? error.message
            : 'Произошла ошибка';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: DeskflowColors.destructiveSolid,
          ),
        );
      }
    });

    Future<void> save() async {
      final deliveryCost =
          parseFormattedNumber(deliveryCostController.text.trim()) ?? 0;
      final notes = notesController.text.trim().isEmpty
          ? null
          : notesController.text.trim();

      final success = await ref
          .read(orderNotifierProvider.notifier)
          .updateOrder(
            orderId: order.id,
            customerId: selectedCustomer.value?.id,
            deliveryCost: deliveryCost,
            notes: notes,
          );

      if (success && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Заказ обновлён')));
        context.pop();
      }
    }

    bool hasUnsavedChanges() {
      final currentDeliveryCost =
          parseFormattedNumber(deliveryCostController.text.trim()) ?? 0;
      final currentNotes = notesController.text.trim().isEmpty
          ? null
          : notesController.text.trim();

      return selectedCustomer.value?.id != order.customerId ||
          currentDeliveryCost != order.deliveryCost ||
          currentNotes != order.notes;
    }

    Future<bool> confirmLeaveForNewOrder() async {
      if (!hasUnsavedChanges()) {
        return true;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: DeskflowColors.glassSurfaceElevated,
          title: const Text('Перейти к новому заказу?'),
          content: const Text(
            'Несохранённые изменения в текущем заказе будут потеряны.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Остаться'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Перейти'),
            ),
          ],
        ),
      );

      return confirmed == true;
    }

    Future<void> saveAsTemplate() async {
      final controller = TextEditingController();
      final savedName = await showDialog<String>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.68),
        builder: (dialogContext) => AlertDialog(
          backgroundColor: DeskflowColors.modalSurface,
          surfaceTintColor: Colors.transparent,
          title: const Text('Новый шаблон'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Название шаблона'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Сохранить шаблон'),
            ),
          ],
        ),
      );

      if (savedName == null || savedName.isEmpty) return;

      final template = await ref
          .read(orderNotifierProvider.notifier)
          .saveOrderTemplate(
            name: savedName,
            composition: OrderComposition.fromOrderItems(order.items),
          );

      if (!context.mounted || template == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Шаблон "${template.name}" сохранён')),
      );
    }

    return WorkScreenScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text('Редактировать ${order.formattedNumber}'),
      ),
      bottomActionBar: WorkPrimaryActionBar(
        key: const Key('edit-order-action-bar'),
        summary: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Сумма заказа',
              style: DeskflowTypography.caption.copyWith(
                color: DeskflowColors.workMutedText,
              ),
            ),
            const SizedBox(height: DeskflowSpacing.xs),
            Text(
              CurrencyFormatter.formatCompact(order.totalAmount),
              style: DeskflowTypography.h3,
            ),
          ],
        ),
        label: 'Сохранить заказ',
        isLoading: isLoading,
        onPressed: isLoading ? null : save,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: bp.isExpanded
                ? 1180
                : (bp.maxContentWidth ?? double.infinity),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: bp.horizontalPadding,
              vertical: DeskflowSpacing.lg,
            ),
            child: bp.isExpanded
                ? Row(
                    key: const Key('edit-order-desktop-layout'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 7,
                        child: Column(
                          key: const Key('edit-order-main-column'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildOrderSummary(selectedCustomer.value),
                            if (order.items.isNotEmpty) ...[
                              const SizedBox(height: DeskflowSpacing.lg),
                              const Text('Товары', style: DeskflowTypography.h3),
                              const SizedBox(height: DeskflowSpacing.sm),
                              _buildItemsCard(),
                            ],
                            const SizedBox(height: DeskflowSpacing.xxl),
                          ],
                        ),
                      ),
                      const SizedBox(width: DeskflowSpacing.xl),
                      Expanded(
                        flex: 5,
                        child: Column(
                          key: const Key('edit-order-side-column'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildQuickSourcesPanel(
                              context: context,
                              templatesAsync: templatesAsync,
                              recentCustomersAsync: recentCustomersAsync,
                              recentProductsAsync: recentProductsAsync,
                              selectedCustomer: selectedCustomer,
                              confirmLeaveForNewOrder: confirmLeaveForNewOrder,
                              saveAsTemplate: saveAsTemplate,
                            ),
                            const SizedBox(height: DeskflowSpacing.lg),
                            _buildDeliverySection(deliveryCostController),
                            const SizedBox(height: DeskflowSpacing.lg),
                            _buildNotesSection(notesController),
                            const SizedBox(height: DeskflowSpacing.xxl),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOrderSummary(selectedCustomer.value),
                      const SizedBox(height: DeskflowSpacing.lg),
                      _buildQuickSourcesPanel(
                        context: context,
                        templatesAsync: templatesAsync,
                        recentCustomersAsync: recentCustomersAsync,
                        recentProductsAsync: recentProductsAsync,
                        selectedCustomer: selectedCustomer,
                        confirmLeaveForNewOrder: confirmLeaveForNewOrder,
                        saveAsTemplate: saveAsTemplate,
                      ),
                      const SizedBox(height: DeskflowSpacing.lg),
                      _buildDeliverySection(deliveryCostController),
                      const SizedBox(height: DeskflowSpacing.lg),
                      _buildNotesSection(notesController),
                      if (order.items.isNotEmpty) ...[
                        const SizedBox(height: DeskflowSpacing.lg),
                        const Text('Товары', style: DeskflowTypography.h3),
                        const SizedBox(height: DeskflowSpacing.sm),
                        _buildItemsCard(),
                      ],
                      const SizedBox(height: DeskflowSpacing.xxl),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderSummary(Customer? customer) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Заказ ${order.formattedNumber}',
            style: DeskflowTypography.h3,
          ),
          if (customer != null) ...[
            const SizedBox(height: DeskflowSpacing.xs),
            Text(
              'Клиент: ${customer.name}',
              style: DeskflowTypography.bodySmall,
            ),
          ],
          if (order.status != null) ...[
            const SizedBox(height: DeskflowSpacing.xs),
            Text(
              'Статус: ${order.status!.name}',
              style: DeskflowTypography.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickSourcesPanel({
    required BuildContext context,
    required AsyncValue<List<OrderTemplate>> templatesAsync,
    required AsyncValue<List<Customer>> recentCustomersAsync,
    required AsyncValue<List<Product>> recentProductsAsync,
    required ValueNotifier<Customer?> selectedCustomer,
    required Future<bool> Function() confirmLeaveForNewOrder,
    required Future<void> Function() saveAsTemplate,
  }) {
    return OrderQuickSourcesPanel(
      templatesAsync: templatesAsync,
      recentCustomersAsync: recentCustomersAsync,
      recentProductsAsync: recentProductsAsync,
      headerAction: TextButton(
        onPressed: order.items.isEmpty ? null : saveAsTemplate,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: DeskflowSpacing.sm),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          minimumSize: Size.zero,
        ),
        child: const Text('Шаблон'),
      ),
      onTemplateTap: (template) async {
        if (!await confirmLeaveForNewOrder()) {
          return;
        }
        if (!context.mounted) {
          return;
        }
        context.push('/orders/create', extra: template.composition);
      },
      onCustomerTap: (customer) => selectedCustomer.value = customer,
      onProductTap: (product) async {
        if (!await confirmLeaveForNewOrder()) {
          return;
        }
        if (!context.mounted) {
          return;
        }
        context.push(
          '/orders/create',
          extra: OrderComposition(
            items: [
              OrderCompositionItem(
                productId: product.id,
                productName: product.name,
                unitPrice: product.price,
                quantity: 1,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeliverySection(TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Стоимость доставки', style: DeskflowTypography.h3),
        const SizedBox(height: DeskflowSpacing.sm),
        GlassCard(
          child: GlassTextField(
            label: 'Доставка',
            hint: '0.00',
            controller: controller,
            textInputAction: TextInputAction.next,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              GroupedNumberTextInputFormatter(allowDecimal: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection(TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Заметки', style: DeskflowTypography.h3),
        const SizedBox(height: DeskflowSpacing.sm),
        GlassCard(
          child: GlassTextField(
            label: 'Заметки к заказу',
            hint: 'Комментарий...',
            controller: controller,
            textInputAction: TextInputAction.done,
            maxLines: 5,
            minLines: 3,
          ),
        ),
      ],
    );
  }

  Widget _buildItemsCard() {
    return GlassCard(
      child: Column(
        children: [
          ...order.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: DeskflowSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${item.productName} ×${item.quantity}',
                      style: DeskflowTypography.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    CurrencyFormatter.formatCompact(
                      item.unitPrice * item.quantity,
                    ),
                    style: DeskflowTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(color: DeskflowColors.glassBorder),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Итого товары', style: DeskflowTypography.body),
              Text(
                CurrencyFormatter.formatCompact(order.itemsTotal),
                style: DeskflowTypography.body.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
