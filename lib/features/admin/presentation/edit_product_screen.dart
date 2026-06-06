import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:deskflow/core/theme/deskflow_theme.dart';
import 'package:deskflow/core/utils/app_logger.dart';
import 'package:deskflow/core/utils/text_input_formatters.dart';
import 'package:deskflow/core/widgets/error_state_widget.dart';
import 'package:deskflow/core/widgets/glass_card.dart';
import 'package:deskflow/core/widgets/glass_text_field.dart';
import 'package:deskflow/core/widgets/skeleton_loader.dart';
import 'package:deskflow/core/widgets/surface_card.dart';
import 'package:deskflow/core/widgets/work_primary_action_bar.dart';
import 'package:deskflow/core/widgets/work_screen_scaffold.dart';
import 'package:deskflow/features/products/domain/product.dart';
import 'package:deskflow/features/products/domain/product_providers.dart';
import 'package:deskflow/features/org/domain/org_providers.dart';

final _log = AppLogger.getLogger('EditProductScreen');

class EditProductScreen extends HookConsumerWidget {
  final String? productId;

  const EditProductScreen({super.key, this.productId});

  bool get isEditing => productId != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isEditing) {
      final productAsync = ref.watch(productDetailProvider(productId!));
      return productAsync.when(        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        data: (product) => _ProductForm(product: product),
        loading: () => Scaffold(
          backgroundColor: DeskflowColors.background,
          appBar: AppBar(title: const Text('Загрузка...')),
          body: SkeletonGroup(
            child: SkeletonLoader(
              child: ListView(
                padding: const EdgeInsets.all(DeskflowSpacing.lg),
                children: [
                  SkeletonLoader.box(height: 200),
                  const SizedBox(height: DeskflowSpacing.lg),
                  SkeletonLoader.box(height: 300),
                ],
              ),
            ),
          ),
        ),
        error: (error, _) => Scaffold(
          backgroundColor: DeskflowColors.background,
          appBar: AppBar(title: const Text('Ошибка')),
          body: ErrorStateWidget(
            message: error.toString(),
            onRetry: () =>
                ref.invalidate(productDetailProvider(productId!)),
          ),
        ),
      );
    }

    return const _ProductForm();
  }
}

class _ProductForm extends HookConsumerWidget {
  final Product? product;

  const _ProductForm({this.product});

  bool get isEditing => product != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameController =
        useTextEditingController(text: product?.name ?? '');
    final skuController =
        useTextEditingController(text: product?.sku ?? '');
    final priceController = useTextEditingController(
        text: product != null ? product!.price.toStringAsFixed(2) : '');
    final descController =
        useTextEditingController(text: product?.description ?? '');
    final isActive = useState(product?.isActive ?? true);
    final isLoading = useState(false);
    final formKey = useMemoized(() => GlobalKey<FormState>());

    final pickedImageBytes = useState<Uint8List?>(null);
    final pickedImageExt = useState<String>('jpg');
    final imageUrl = useState<String?>(product?.imageUrl);
    final isUploadingImage = useState(false);
    final bp = DeskflowBreakpoints.of(context);

    Future<void> pickImage() async {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final ext = picked.path.split('.').last.toLowerCase();
      pickedImageBytes.value = bytes;
      pickedImageExt.value = (ext == 'png' || ext == 'webp') ? ext : 'jpeg';
    }

    Future<String?> uploadImage(String productId) async {
      if (pickedImageBytes.value == null) return imageUrl.value;
      isUploadingImage.value = true;
      try {
        final orgId = ref.read(currentOrgIdProvider);
        if (orgId == null) return imageUrl.value;
        final url = await ref.read(productRepositoryProvider).uploadProductImage(
              orgId: orgId,
              productId: productId,
              bytes: pickedImageBytes.value!,
              fileExt: pickedImageExt.value,
            );
        imageUrl.value = url;
        return url;
      } catch (e) {
        _log.e('uploadImage failed: $e');
        return imageUrl.value;
      } finally {
        isUploadingImage.value = false;
      }
    }

    Future<void> save() async {
      if (!formKey.currentState!.validate()) return;

      final orgId = ref.read(currentOrgIdProvider);
      if (orgId == null) return;

      isLoading.value = true;
      try {
        final repo = ref.read(productRepositoryProvider);
        final price =
            parseFormattedNumber(priceController.text.trim()) ?? 0.0;

        if (isEditing) {
          final uploadedUrl = await uploadImage(product!.id);

          await repo.updateProduct(
            productId: product!.id,
            name: nameController.text.trim(),
            price: price,
            sku: skuController.text.trim().isEmpty
                ? null
                : skuController.text.trim(),
            description: descController.text.trim().isEmpty
                ? null
                : descController.text.trim(),
            imageUrl: uploadedUrl,
            isActive: isActive.value,
          );
          ref.invalidate(productDetailProvider(product!.id));
        } else {
          final created = await repo.createProduct(
            orgId: orgId,
            name: nameController.text.trim(),
            price: price,
            sku: skuController.text.trim().isEmpty
                ? null
                : skuController.text.trim(),
            description: descController.text.trim().isEmpty
                ? null
                : descController.text.trim(),
          );

          if (pickedImageBytes.value != null) {
            final uploadedUrl = await uploadImage(created.id);
            if (uploadedUrl != null) {
              await repo.updateProduct(
                productId: created.id,
                name: created.name,
                price: created.price,
                imageUrl: uploadedUrl,
              );
            }
          }
        }

        ref.invalidate(productsListProvider());

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEditing ? 'Товар обновлён' : 'Товар создан'),
            ),
          );
          context.pop();
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

    Future<void> delete() async {
      if (product == null) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: DeskflowColors.modalSurface,
          title: const Text('Удалить товар'),
          content: Text('Удалить «${product!.name}»?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(
                foregroundColor: DeskflowColors.destructiveSolid,
              ),
              child: const Text('Удалить'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
      if (!context.mounted) return;

      try {
        await ref
            .read(productRepositoryProvider)
            .updateProduct(
              productId: product!.id,
              name: product!.name,
              price: product!.price,
              isActive: false,
            );
        ref.invalidate(productsListProvider());
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Товар деактивирован')),
          );
          context.pop();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      }
    }

    return WorkScreenScaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Редактировать товар' : 'Новый товар'),
      ),
      bottomActionBar: WorkPrimaryActionBar(
        key: const Key('edit-product-action-bar'),
        summary: ValueListenableBuilder<TextEditingValue>(
          valueListenable: nameController,
          builder: (context, value, _) {
            final name = value.text.trim();
            final displayName = name.isEmpty ? 'Без названия' : name;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isEditing ? 'Редактирование товара' : 'Новый товар',
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
        label: 'Сохранить',
        onPressed: isLoading.value ? null : save,
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
              maxWidth: bp.isExpanded ? 1160 : (bp.maxContentWidth ?? double.infinity),
            ),
            child: Form(
              key: formKey,
              child: bp.isExpanded
                  ? Row(
                      key: const Key('edit-product-desktop-layout'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 7,
                          child: Column(
                            key: const Key('edit-product-main-column'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildMainFields(
                                nameController,
                                skuController,
                                priceController,
                              ),
                              const SizedBox(height: DeskflowSpacing.lg),
                              _buildDescriptionSection(descController),
                              const SizedBox(height: DeskflowSpacing.xxl),
                            ],
                          ),
                        ),
                        const SizedBox(width: DeskflowSpacing.xl),
                        Expanded(
                          flex: 5,
                          child: Column(
                            key: const Key('edit-product-side-column'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildPhotoSection(
                                pickImage,
                                pickedImageBytes,
                                imageUrl,
                              ),
                              const SizedBox(height: DeskflowSpacing.lg),
                              _buildStateSection(isActive),
                              if (isEditing) ...[
                                const SizedBox(height: DeskflowSpacing.md),
                                TextButton(
                                  onPressed: delete,
                                  style: TextButton.styleFrom(
                                    foregroundColor:
                                        DeskflowColors.destructiveSolid,
                                  ),
                                  child: const Text('Удалить товар'),
                                ),
                              ],
                              const SizedBox(height: DeskflowSpacing.xxl),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildPhotoSection(
                          pickImage,
                          pickedImageBytes,
                          imageUrl,
                        ),
                        const SizedBox(height: DeskflowSpacing.lg),
                        _buildMainFields(
                          nameController,
                          skuController,
                          priceController,
                        ),
                        const SizedBox(height: DeskflowSpacing.lg),
                        _buildDescriptionSection(descController),
                        const SizedBox(height: DeskflowSpacing.lg),
                        _buildStateSection(isActive),
                        if (isEditing) ...[
                          const SizedBox(height: DeskflowSpacing.md),
                          TextButton(
                            onPressed: delete,
                            style: TextButton.styleFrom(
                              foregroundColor: DeskflowColors.destructiveSolid,
                            ),
                            child: const Text('Удалить товар'),
                          ),
                        ],
                        const SizedBox(height: DeskflowSpacing.xxl),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSection(
    Future<void> Function() pickImage,
    ValueNotifier<Uint8List?> pickedImageBytes,
    ValueNotifier<String?> imageUrl,
  ) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Фото', style: DeskflowTypography.caption),
          const SizedBox(height: DeskflowSpacing.md),
          GestureDetector(
            onTap: pickImage,
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                color: DeskflowColors.glassSurface,
                borderRadius: BorderRadius.circular(DeskflowRadius.md),
                border: Border.all(
                  color: DeskflowColors.glassBorder,
                  width: 0.5,
                ),
              ),
              child: pickedImageBytes.value != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(DeskflowRadius.md),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(
                            pickedImageBytes.value!,
                            fit: BoxFit.cover,
                          ),
                          const _EditPhotoBadge(),
                        ],
                      ),
                    )
                  : imageUrl.value != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(DeskflowRadius.md),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: imageUrl.value!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorWidget: (_, _, _) =>
                                    const _PhotoPlaceholder(),
                              ),
                              const _EditPhotoBadge(),
                            ],
                          ),
                        )
                      : const _PhotoPlaceholder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainFields(
    TextEditingController nameController,
    TextEditingController skuController,
    TextEditingController priceController,
  ) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Основное', style: DeskflowTypography.caption),
          const SizedBox(height: DeskflowSpacing.md),
          GlassTextField(
            label: 'Название',
            hint: 'Название товара',
            controller: nameController,
            textInputAction: TextInputAction.next,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Введите название';
              }
              if (v.trim().length > 200) {
                return 'Макс. 200 символов';
              }
              return null;
            },
          ),
          const SizedBox(height: DeskflowSpacing.md),
          GlassTextField(
            label: 'Артикул (SKU)',
            hint: 'ABC-123',
            controller: skuController,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: DeskflowSpacing.md),
          GlassTextField(
            label: 'Цена',
            hint: '0.00',
            controller: priceController,
            textInputAction: TextInputAction.next,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              GroupedNumberTextInputFormatter(allowDecimal: true),
            ],
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Введите цену';
              }
              final price = parseFormattedNumber(v.trim());
              if (price == null || price < 0) {
                return 'Некорректная цена';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection(TextEditingController descController) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Описание', style: DeskflowTypography.caption),
          const SizedBox(height: DeskflowSpacing.md),
          GlassTextField(
            label: 'Описание товара',
            hint: 'Подробное описание...',
            controller: descController,
            textInputAction: TextInputAction.done,
            maxLines: 5,
            minLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildStateSection(ValueNotifier<bool> isActive) {
    return SurfaceCard(
      variant: SurfaceCardVariant.elevated,
      child: SwitchListTile(
        title: const Text(
          'Активный',
          style: DeskflowTypography.body,
        ),
        subtitle: Text(
          'Неактивные товары скрыты из каталога',
          style: DeskflowTypography.caption,
        ),
        value: isActive.value,
        onChanged: (v) => isActive.value = v,
        activeThumbColor: DeskflowColors.successSolid,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

class _EditPhotoBadge extends StatelessWidget {
  const _EditPhotoBadge();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: DeskflowSpacing.sm,
      right: DeskflowSpacing.sm,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DeskflowSpacing.sm,
          vertical: DeskflowSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(DeskflowRadius.sm),
        ),
        child: const Text(
          'Изменить',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_a_photo_rounded,
            color: DeskflowColors.textTertiary,
            size: 40,
          ),
          SizedBox(height: DeskflowSpacing.sm),
          Text(
            'Добавить фото',
            style: DeskflowTypography.caption,
          ),
        ],
      ),
    );
  }
}
