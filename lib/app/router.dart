import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/items/item_detail_screen.dart';
import '../features/items/item_form_screen.dart';
import '../features/items/items_list_screen.dart';
import '../features/scan/scan_screen.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const ItemsListScreen(),
    ),
    GoRoute(
      path: '/scan',
      builder: (context, state) => const ScanScreen(),
    ),
    GoRoute(
      path: '/items/new',
      builder: (context, state) {
        final extra = state.extra;
        final args = extra is ItemFormArgs ? extra : const ItemFormArgs();
        return ItemFormScreen(args: args);
      },
    ),
    GoRoute(
      path: '/items/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return ItemDetailScreen(itemId: id);
      },
    ),
    GoRoute(
      path: '/items/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return ItemFormScreen(args: ItemFormArgs(editId: id));
      },
    ),
  ],
);

/// Quick entry for weighed goods from the list FAB menu (optional).
void openWeighedItemForm(BuildContext context) {
  context.push(
    '/items/new',
    extra: const ItemFormArgs(forceWeighed: true),
  );
}
