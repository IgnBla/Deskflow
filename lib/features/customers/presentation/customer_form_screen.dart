import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:deskflow/core/errors/deskflow_exception.dart';
import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/widgets/glass_card.dart';
import 'package:deskflow/core/widgets/glass_text_field.dart';
import 'package:deskflow/core/widgets/error_state_widget.dart';
import 'package:deskflow/core/widgets/skeleton_loader.dart';
import 'package:deskflow/core/widgets/surface_card.dart';
import 'package:deskflow/core/widgets/work_primary_action_bar.dart';
import 'package:deskflow/core/widgets/work_screen_scaffold.dart';
import 'package:deskflow/features/customers/domain/customer_providers.dart';
import 'package:deskflow/features/orders/domain/customer.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';

class CustomerFormScreen extends HookConsumerWidget {
  final String? customerId;

  const CustomerFormScreen({super.key, this.customerId});

  bool get isEditing => customerId != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync =
        isEditing ? ref.watch(customerDetailProvider(customerId!)) : null;

    if (isEditing) {
      return customerAsync!.when(          skipLoadingOnRefresh: true,
          skipLoadingOnReload: true,
          data: (customer) => _CustomerForm(
            customer: customer,
            customerId: customerId,
          ),
          loading: () => const _FormSkeleton(),
          error: (error, _) => ErrorStateWidget(
            message: error.toString(),
            onRetry: () =>
                ref.invalidate(customerDetailProvider(customerId!)),
          ),
        );
    }

    return const _CustomerForm();
  }
}

class _CustomerForm extends HookConsumerWidget {
  final Customer? customer;
  final String? customerId;

  const _CustomerForm({this.customer, this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final isLoading = useState(false);

    final nameCtrl = useTextEditingController(text: customer?.name ?? '');
    final phoneCtrl = useTextEditingController(text: customer?.phone ?? '');
    final emailCtrl = useTextEditingController(text: customer?.email ?? '');
    final addressCtrl =
        useTextEditingController(text: customer?.address ?? '');
    final notesCtrl = useTextEditingController(text: customer?.notes ?? '');
    final bp = DeskflowBreakpoints.of(context);

    Future<void> handleSave() async {
      if (!formKey.currentState!.validate()) return;

      isLoading.value = true;
      try {
        final repo = ref.read(customerRepositoryProvider);

        if (customerId != null) {
          await repo.updateCustomer(
            customerId: customerId!,
            name: nameCtrl.text.trim(),
            phone: phoneCtrl.text.trim().isEmpty
                ? null
                : phoneCtrl.text.trim(),
            email: emailCtrl.text.trim().isEmpty
                ? null
                : emailCtrl.text.trim(),
            address: addressCtrl.text.trim().isEmpty
                ? null
                : addressCtrl.text.trim(),
            notes: notesCtrl.text.trim().isEmpty
                ? null
                : notesCtrl.text.trim(),
          );
          ref.invalidate(customerDetailProvider(customerId!));
        } else {
          final orgId = ref.read(currentOrgIdProvider);
          if (orgId == null) return;

          await repo.createCustomer(
            orgId: orgId,
            name: nameCtrl.text.trim(),
            phone: phoneCtrl.text.trim().isEmpty
                ? null
                : phoneCtrl.text.trim(),
            email: emailCtrl.text.trim().isEmpty
                ? null
                : emailCtrl.text.trim(),
            address: addressCtrl.text.trim().isEmpty
                ? null
                : addressCtrl.text.trim(),
            notes: notesCtrl.text.trim().isEmpty
                ? null
                : notesCtrl.text.trim(),
          );
        }

        ref.invalidate(customersListProvider);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(customerId != null
                  ? 'Клиент обновлён'
                  : 'Клиент создан'),
            ),
          );
          context.pop();
        }
      } on DeskflowException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: DeskflowColors.destructive,
            ),
          );
        }
      } finally {
        isLoading.value = false;
      }
    }

    return WorkScreenScaffold(
      appBar: AppBar(
        title: Text(customerId != null ? 'Редактировать клиента' : 'Новый клиент'),
      ),
      bottomActionBar: WorkPrimaryActionBar(
        key: const Key('customer-form-action-bar'),
        summary: ValueListenableBuilder<TextEditingValue>(
          valueListenable: nameCtrl,
          builder: (context, value, _) {
            final name = value.text.trim();
            final displayName = name.isEmpty ? 'Без имени' : name;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  customerId != null ? 'Карточка клиента' : 'Новый контакт',
                  style: DeskflowTypography.caption.copyWith(
                    color: DeskflowColors.workMutedText,
                  ),
                ),
                const SizedBox(height: DeskflowSpacing.xs),
                Text(
                  displayName,
                  style: DeskflowTypography.h3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            );
          },
        ),
        label: customerId != null ? 'Сохранить' : 'Создать клиента',
        onPressed: isLoading.value ? null : handleSave,
        isLoading: isLoading.value,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: bp.horizontalPadding,
          vertical: DeskflowSpacing.lg,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: bp.isExpanded ? 1120 : (bp.maxContentWidth ?? double.infinity),
            ),
            child: Form(
              key: formKey,
              child: bp.isExpanded
                  ? Row(
                      key: const Key('customer-form-desktop-layout'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 7,
                          child: Column(
                            key: const Key('customer-form-main-column'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildPrimarySection(nameCtrl),
                              const SizedBox(height: DeskflowSpacing.lg),
                              _buildContactsSection(
                                phoneCtrl,
                                emailCtrl,
                                addressCtrl,
                              ),
                              const SizedBox(height: DeskflowSpacing.xxl),
                            ],
                          ),
                        ),
                        const SizedBox(width: DeskflowSpacing.xl),
                        Expanded(
                          flex: 5,
                          child: Column(
                            key: const Key('customer-form-side-column'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildSummaryPanel(),
                              const SizedBox(height: DeskflowSpacing.lg),
                              _buildNotesSection(notesCtrl),
                              const SizedBox(height: DeskflowSpacing.xxl),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildPrimarySection(nameCtrl),
                        const SizedBox(height: DeskflowSpacing.lg),
                        _buildContactsSection(
                          phoneCtrl,
                          emailCtrl,
                          addressCtrl,
                        ),
                        const SizedBox(height: DeskflowSpacing.lg),
                        _buildNotesSection(notesCtrl),
                        const SizedBox(height: DeskflowSpacing.xxl),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimarySection(TextEditingController nameCtrl) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(DeskflowSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Основная информация', style: DeskflowTypography.h3),
            const SizedBox(height: DeskflowSpacing.lg),
            GlassTextField(
              controller: nameCtrl,
              label: 'Имя *',
              hint: 'Иван Иванов',
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Введите имя клиента';
                }
                if (value.trim().length > 200) {
                  return 'Максимум 200 символов';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactsSection(
    TextEditingController phoneCtrl,
    TextEditingController emailCtrl,
    TextEditingController addressCtrl,
  ) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(DeskflowSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Контакты', style: DeskflowTypography.h3),
            const SizedBox(height: DeskflowSpacing.lg),
            GlassTextField(
              controller: phoneCtrl,
              label: 'Телефон',
              hint: '+7 (777) 123-45-67',
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: DeskflowSpacing.md),
            GlassTextField(
              controller: emailCtrl,
              label: 'Email',
              hint: 'client@example.com',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  if (!value.contains('@') || !value.contains('.')) {
                    return 'Некорректный email';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: DeskflowSpacing.md),
            GlassTextField(
              controller: addressCtrl,
              label: 'Адрес',
              hint: 'г. Алматы, ул. Абая 1',
              textInputAction: TextInputAction.next,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection(TextEditingController notesCtrl) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(DeskflowSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Заметки', style: DeskflowTypography.h3),
            const SizedBox(height: DeskflowSpacing.lg),
            GlassTextField(
              controller: notesCtrl,
              label: 'Заметки о клиенте',
              hint: 'Любая дополнительная информация...',
              textInputAction: TextInputAction.done,
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryPanel() {
    return SurfaceCard(
      variant: SurfaceCardVariant.elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            customerId != null ? 'Режим редактирования' : 'Новый клиент',
            style: DeskflowTypography.h3,
          ),
          const SizedBox(height: DeskflowSpacing.sm),
          Text(
            customerId != null
                ? 'Проверьте контакты и заметки перед сохранением.'
                : 'Заполните контакты и добавьте заметку, если она нужна команде.',
            style: DeskflowTypography.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _FormSkeleton extends StatelessWidget {
  const _FormSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonGroup(
      child: SkeletonLoader(
        child: ListView(
          padding: const EdgeInsets.all(DeskflowSpacing.lg),
          children: [
            SkeletonLoader.box(height: 160),
            const SizedBox(height: DeskflowSpacing.lg),
            SkeletonLoader.box(height: 240),
            const SizedBox(height: DeskflowSpacing.lg),
            SkeletonLoader.box(height: 160),
          ],
        ),
      ),
    );
  }
}
