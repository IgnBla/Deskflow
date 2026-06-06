import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/widgets/work_screen_scaffold.dart';
import 'package:deskflow/core/widgets/work_settings_group.dart';
import 'package:deskflow/features/profile/domain/profile_providers.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(notificationSettingsNotifierProvider);
    final bp = DeskflowBreakpoints.of(context);

    return WorkScreenScaffold(
      appBar: AppBar(title: const Text('Уведомления')),
      body: settingsAsync.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Ошибка загрузки: $error',
            style: DeskflowTypography.body.copyWith(
              color: DeskflowColors.destructiveSolid,
            ),
          ),
        ),
        data: (settings) => SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: bp.horizontalPadding,
            vertical: DeskflowSpacing.lg,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth:
                    bp.isExpanded ? 880 : (bp.maxContentWidth ?? double.infinity),
              ),
              child: WorkSettingsGroup(
                title: 'Настройки уведомлений',
                children: [
                  _NotificationRow(
                    title: 'Новые заказы',
                    subtitle: 'Уведомлять о новых заказах',
                    icon: Icons.add_shopping_cart_rounded,
                    value: settings.notifyNewOrders,
                    onChanged: (value) => ref
                        .read(notificationSettingsNotifierProvider.notifier)
                        .updateSetting(notifyNewOrders: value),
                  ),
                  _NotificationRow(
                    title: 'Изменения статуса',
                    subtitle: 'Уведомлять при смене статуса заказа',
                    icon: Icons.swap_horiz_rounded,
                    value: settings.notifyStatusChanges,
                    onChanged: (value) => ref
                        .read(notificationSettingsNotifierProvider.notifier)
                        .updateSetting(notifyStatusChanges: value),
                  ),
                  _NotificationRow(
                    title: 'Сообщения в чате',
                    subtitle: 'Уведомлять о новых сообщениях',
                    icon: Icons.chat_rounded,
                    value: settings.notifyChatMessages,
                    onChanged: (value) => ref
                        .read(notificationSettingsNotifierProvider.notifier)
                        .updateSetting(notifyChatMessages: value),
                  ),
                  _NotificationRow(
                    title: 'Звук уведомлений',
                    subtitle: 'Воспроизводить звук',
                    icon: Icons.volume_up_rounded,
                    value: settings.notifySound,
                    onChanged: (value) => ref
                        .read(notificationSettingsNotifierProvider.notifier)
                        .updateSetting(notifySound: value),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: DeskflowSpacing.lg,
        vertical: DeskflowSpacing.xs,
      ),
      leading: Icon(icon, color: DeskflowColors.textSecondary, size: 22),
      title: Text(title, style: DeskflowTypography.body),
      subtitle: Text(subtitle, style: DeskflowTypography.caption),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: DeskflowColors.primarySolid,
      ),
    );
  }
}
