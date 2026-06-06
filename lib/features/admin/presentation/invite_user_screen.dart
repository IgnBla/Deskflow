import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:deskflow/core/errors/deskflow_exception.dart';
import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/core/widgets/glass_text_field.dart';
import 'package:deskflow/core/widgets/pill_button.dart';
import 'package:deskflow/core/widgets/surface_card.dart';
import 'package:deskflow/core/widgets/work_primary_action_bar.dart';
import 'package:deskflow/core/widgets/work_screen_scaffold.dart';
import 'package:deskflow/features/admin/domain/admin_providers.dart';
import 'package:deskflow/features/org/domain/org_member.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';
import 'package:deskflow/features/org/domain/organization.dart';

final _log = AppLogger.getLogger('InviteUserScreen');

class InviteUserScreen extends HookConsumerWidget {
  const InviteUserScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailController = useTextEditingController();
    final selectedRole = useState(OrgRole.member);
    final isLoading = useState(false);
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final orgsAsync = ref.watch(userOrganizationsProvider);
    final orgId = ref.watch(currentOrgIdProvider);
    final bp = DeskflowBreakpoints.of(context);

    Future<void> invite() async {
      if (!formKey.currentState!.validate()) return;

      final currentOrgId = ref.read(currentOrgIdProvider);
      if (currentOrgId == null) return;

      isLoading.value = true;
      try {
        await ref.read(adminRepositoryProvider).inviteMember(
              orgId: currentOrgId,
              email: emailController.text.trim(),
              role: selectedRole.value,
            );
        ref.invalidate(orgMembersProvider);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Участник добавлен')),
          );
          context.pop();
        }
      } catch (e) {
        _log.w('[FIX] inviteMember error: $e');
        if (context.mounted) {
          final message =
              e is DeskflowException ? e.message : 'Произошла ошибка';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      } finally {
        isLoading.value = false;
      }
    }

    return WorkScreenScaffold(
      appBar: AppBar(title: const Text('Пригласить участника')),
      bottomActionBar: WorkPrimaryActionBar(
        summary: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Роль приглашения',
              style: DeskflowTypography.caption.copyWith(
                color: DeskflowColors.workMutedText,
              ),
            ),
            const SizedBox(height: DeskflowSpacing.xs),
            Text(selectedRole.value.label, style: DeskflowTypography.h3),
          ],
        ),
        label: 'Отправить приглашение',
        onPressed: isLoading.value ? null : invite,
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
            child: Form(
              key: formKey,
              child: bp.isExpanded
                  ? Row(
                      key: const Key('invite-user-desktop-layout'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 7,
                          child: Column(
                            key: const Key('invite-user-main-column'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _InviteFormCard(
                                emailController: emailController,
                                selectedRole: selectedRole,
                                onSubmit: invite,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: DeskflowSpacing.xl),
                        Expanded(
                          flex: 5,
                          child: Column(
                            key: const Key('invite-user-side-column'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _InviteCodeCard(
                                orgsAsync: orgsAsync,
                                orgId: orgId,
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _InviteFormCard(
                          emailController: emailController,
                          selectedRole: selectedRole,
                          onSubmit: invite,
                        ),
                        const SizedBox(height: DeskflowSpacing.lg),
                        _InviteCodeCard(
                          orgsAsync: orgsAsync,
                          orgId: orgId,
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

class _InviteFormCard extends StatelessWidget {
  const _InviteFormCard({
    required this.emailController,
    required this.selectedRole,
    required this.onSubmit,
  });

  final TextEditingController emailController;
  final ValueNotifier<OrgRole> selectedRole;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final bp = DeskflowBreakpoints.of(context);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('По email', style: DeskflowTypography.caption),
          const SizedBox(height: DeskflowSpacing.md),
          GlassTextField(
            label: 'Email',
            hint: 'user@example.com',
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSubmit(),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Введите email';
              }
              if (!value.contains('@')) {
                return 'Некорректный email';
              }
              return null;
            },
          ),
          const SizedBox(height: DeskflowSpacing.lg),
          Text('Роль', style: DeskflowTypography.caption),
          const SizedBox(height: DeskflowSpacing.sm),
          bp.isExpanded
              ? Row(
                  children: OrgRole.values.map((role) {
                    final selected = selectedRole.value == role;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right:
                              role != OrgRole.values.last ? DeskflowSpacing.sm : 0,
                        ),
                        child: _RoleOptionTile(
                          role: role,
                          selected: selected,
                          onTap: () => selectedRole.value = role,
                        ),
                      ),
                    );
                  }).toList(),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: OrgRole.values.map((role) {
                    final selected = selectedRole.value == role;
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom:
                            role != OrgRole.values.last ? DeskflowSpacing.sm : 0,
                      ),
                      child: _RoleOptionTile(
                        role: role,
                        selected: selected,
                        onTap: () => selectedRole.value = role,
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }
}

class _RoleOptionTile extends StatelessWidget {
  const _RoleOptionTile({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final OrgRole role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DeskflowSpacing.sm,
          vertical: DeskflowSpacing.md,
        ),
        decoration: BoxDecoration(
          color: selected
              ? DeskflowColors.primarySolid.withValues(alpha: 0.16)
              : DeskflowColors.workSurfaceElevated,
          borderRadius: BorderRadius.circular(DeskflowRadius.md),
          border: Border.all(
            color: selected
                ? DeskflowColors.primarySolid
                : DeskflowColors.workBorder,
            width: selected ? 1.25 : 0.5,
          ),
        ),
        child: Center(
          child: Text(
            role.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DeskflowTypography.body.copyWith(
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected
                  ? DeskflowColors.primarySolid
                  : DeskflowColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({
    required this.orgsAsync,
    required this.orgId,
  });

  final AsyncValue<List<Organization>> orgsAsync;
  final String? orgId;

  @override
  Widget build(BuildContext context) {
    return orgsAsync.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      data: (orgs) {
        final currentOrg = orgs.where((org) => org.id == orgId).firstOrNull;
        if (currentOrg?.inviteCode == null) {
          return const SizedBox.shrink();
        }

        const webHost = 'https://deskflow.app';
        final joinLink = '$webHost/org/join?code=${currentOrg!.inviteCode}';
        final inviteMessage = 'Присоединяйтесь к организации '
            '«${currentOrg.name}» в Deskflow!\n\n'
            'Перейдите по ссылке:\n$joinLink\n\n'
            'Или введите код приглашения вручную: ${currentOrg.inviteCode}';

        return SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Или по коду приглашения', style: DeskflowTypography.caption),
              const SizedBox(height: DeskflowSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DeskflowSpacing.md,
                        vertical: DeskflowSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: DeskflowColors.workSurfaceElevated,
                        borderRadius: BorderRadius.circular(DeskflowRadius.md),
                      ),
                      child: Text(
                        currentOrg.inviteCode!,
                        style: DeskflowTypography.body.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: DeskflowSpacing.sm),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded),
                    tooltip: 'Копировать код',
                    onPressed: () {
                      _log.d('[FIX] Copying invite code for org=${currentOrg.name}');
                      Clipboard.setData(
                        ClipboardData(text: currentOrg.inviteCode!),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Код скопирован')),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: DeskflowSpacing.md),
              SizedBox(
                width: double.infinity,
                child: PillButton.secondary(
                  label: 'Поделиться приглашением',
                  icon: Icons.share_rounded,
                  onPressed: () async {
                    _log.d('[FIX] Sharing invite link for org=${currentOrg.name}, '
                        'code=${currentOrg.inviteCode}');
                    try {
                      final result = await Share.share(
                        inviteMessage,
                        subject: 'Приглашение в ${currentOrg.name}',
                      );
                      _log.d('[FIX] Share result: status=${result.status}');
                    } catch (e) {
                      _log.e('[FIX] Share failed', error: e);
                      await Clipboard.setData(ClipboardData(text: inviteMessage));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Приглашение скопировано в буфер обмена'),
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
