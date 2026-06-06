import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/utils/pluralize_ru.dart';
import 'package:deskflow/core/widgets/glass_text_field.dart';
import 'package:deskflow/core/widgets/surface_card.dart';
import 'package:deskflow/core/widgets/work_primary_action_bar.dart';
import 'package:deskflow/core/widgets/work_screen_scaffold.dart';
import 'package:deskflow/features/admin/domain/admin_providers.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';

class OrgSettingsScreen extends HookConsumerWidget {
  const OrgSettingsScreen({super.key});

  String _membersLabel(int count) {
    return '$count ${pluralizeRu(count, 'участник', 'участника', 'участников')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgsAsync = ref.watch(userOrganizationsProvider);
    final orgId = ref.watch(currentOrgIdProvider);
    final membersAsync = ref.watch(orgMembersProvider);
    final nameController = useTextEditingController();
    final isLoading = useState(false);
    final initialized = useState(false);
    final bp = DeskflowBreakpoints.of(context);

    orgsAsync.whenData((orgs) {
      if (!initialized.value) {
        final org = orgs.where((item) => item.id == orgId).firstOrNull;
        if (org != null) {
          nameController.text = org.name;
          initialized.value = true;
        }
      }
    });

    Future<void> saveName() async {
      if (orgId == null) return;
      final name = nameController.text.trim();
      if (name.isEmpty) return;

      isLoading.value = true;
      try {
        await ref.read(adminRepositoryProvider).updateOrganization(
              orgId: orgId,
              name: name,
            );
        ref.invalidate(userOrganizationsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Название обновлено')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      } finally {
        isLoading.value = false;
      }
    }

    void showDeleteConfirmation() {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Удалить организацию'),
          content: const Text(
            'Вы уверены? Это действие нельзя отменить. Все данные организации будут удалены.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx2) => AlertDialog(
                    title: const Text('Точно удалить?'),
                    content: const Text('Введите УДАЛИТЬ для подтверждения.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx2, false),
                        child: const Text('Отмена'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx2, true),
                        style: TextButton.styleFrom(
                          foregroundColor: DeskflowColors.destructiveSolid,
                        ),
                        child: const Text('Удалить навсегда'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true || !context.mounted) return;

                try {
                  await ref.read(adminRepositoryProvider).deleteOrganization(orgId!);
                  ref.read(currentOrgIdProvider.notifier).clear();
                  ref.invalidate(userOrganizationsProvider);
                  if (context.mounted) {
                    context.go('/org/select');
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: DeskflowColors.destructiveSolid,
              ),
              child: const Text('Удалить'),
            ),
          ],
        ),
      );
    }

    return WorkScreenScaffold(
      appBar: AppBar(title: const Text('Настройки организации')),
      bottomActionBar: WorkPrimaryActionBar(
        summary: ValueListenableBuilder<TextEditingValue>(
          valueListenable: nameController,
          builder: (context, value, _) {
            final name = value.text.trim();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Организация',
                  style: DeskflowTypography.caption.copyWith(
                    color: DeskflowColors.workMutedText,
                  ),
                ),
                const SizedBox(height: DeskflowSpacing.xs),
                Text(
                  name.isEmpty ? 'Без названия' : name,
                  style: DeskflowTypography.h3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            );
          },
        ),
        label: 'Сохранить',
        onPressed: isLoading.value ? null : saveName,
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
              maxWidth:
                  bp.isExpanded ? 1120 : (bp.maxContentWidth ?? double.infinity),
            ),
            child: bp.isExpanded
                ? Row(
                    key: const Key('org-settings-desktop-layout'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 7,
                        child: Column(
                          key: const Key('org-settings-main-column'),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SurfaceCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Основное', style: DeskflowTypography.caption),
                                  const SizedBox(height: DeskflowSpacing.md),
                                  GlassTextField(
                                    label: 'Название организации',
                                    hint: 'Моя компания',
                                    controller: nameController,
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) => saveName(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: DeskflowSpacing.lg),
                            SurfaceCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Участники', style: DeskflowTypography.caption),
                                  const SizedBox(height: DeskflowSpacing.md),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      membersAsync.when(
                                        skipLoadingOnRefresh: true,
                                        skipLoadingOnReload: true,
                                        data: (members) => Text(
                                          _membersLabel(members.length),
                                          style: DeskflowTypography.body,
                                        ),
                                        loading: () => const Text('Загрузка...'),
                                        error: (_, _) => const Text('Ошибка'),
                                      ),
                                      TextButton.icon(
                                        icon: const Icon(Icons.people_rounded, size: 18),
                                        label: const Text('Управление'),
                                        onPressed: () => context.push('/admin/users'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: DeskflowSpacing.xl),
                      Expanded(
                        flex: 5,
                        child: Column(
                          key: const Key('org-settings-side-column'),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SurfaceCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Опасная зона',
                                    style: DeskflowTypography.caption.copyWith(
                                      color: DeskflowColors.destructiveSolid,
                                    ),
                                  ),
                                  const SizedBox(height: DeskflowSpacing.md),
                                  Text(
                                    'Удаление организации сотрёт все связанные данные без возможности восстановления.',
                                    style: DeskflowTypography.bodySmall.copyWith(
                                      color: DeskflowColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: DeskflowSpacing.lg),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      icon: const Icon(Icons.delete_forever_rounded),
                                      label: const Text('Удалить организацию'),
                                      onPressed: showDeleteConfirmation,
                                      style: TextButton.styleFrom(
                                        foregroundColor:
                                            DeskflowColors.destructiveSolid,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Основное', style: DeskflowTypography.caption),
                            const SizedBox(height: DeskflowSpacing.md),
                            GlassTextField(
                              label: 'Название организации',
                              hint: 'Моя компания',
                              controller: nameController,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => saveName(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: DeskflowSpacing.lg),
                      SurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Участники', style: DeskflowTypography.caption),
                            const SizedBox(height: DeskflowSpacing.md),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                membersAsync.when(
                                  skipLoadingOnRefresh: true,
                                  skipLoadingOnReload: true,
                                  data: (members) => Text(
                                    _membersLabel(members.length),
                                    style: DeskflowTypography.body,
                                  ),
                                  loading: () => const Text('Загрузка...'),
                                  error: (_, _) => const Text('Ошибка'),
                                ),
                                TextButton.icon(
                                  icon: const Icon(Icons.people_rounded, size: 18),
                                  label: const Text('Управление'),
                                  onPressed: () => context.push('/admin/users'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: DeskflowSpacing.lg),
                      SurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Опасная зона',
                              style: DeskflowTypography.caption.copyWith(
                                color: DeskflowColors.destructiveSolid,
                              ),
                            ),
                            const SizedBox(height: DeskflowSpacing.md),
                            TextButton.icon(
                              icon: const Icon(Icons.delete_forever_rounded),
                              label: const Text('Удалить организацию'),
                              onPressed: showDeleteConfirmation,
                              style: TextButton.styleFrom(
                                foregroundColor:
                                    DeskflowColors.destructiveSolid,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
