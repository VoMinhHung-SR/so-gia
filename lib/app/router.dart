import 'package:go_router/go_router.dart';

import '../features/backup/backup_screen.dart';
import '../features/items/item_detail_screen.dart';
import '../features/items/item_form_screen.dart';
import '../features/items/items_list_screen.dart';
import '../features/pricing/compare_items_screen.dart';
import '../features/ref_prices/ref_price_lookup_screen.dart';
import '../features/scan/pending_supplements_screen.dart';
import '../features/scan/scan_screen.dart';
import '../features/settings/about_sources_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/suppliers/suppliers_screen.dart';

GoRouter buildAppRouter({bool startOnScan = false}) {
  return GoRouter(
    initialLocation: startOnScan ? '/scan' : '/',
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
        path: '/pending-supplements',
        builder: (context, state) => const PendingSupplementsScreen(),
      ),
      GoRoute(
        path: '/suppliers',
        builder: (context, state) => const SuppliersScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/about-sources',
        builder: (context, state) => const AboutSourcesScreen(),
      ),
      GoRoute(
        path: '/backup',
        builder: (context, state) => const BackupScreen(),
      ),
      GoRoute(
        path: '/compare',
        builder: (context, state) {
          final cat = state.uri.queryParameters['category'];
          return CompareItemsScreen(category: cat);
        },
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
      GoRoute(
        path: '/items/:id/ref-price',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return RefPriceLookupScreen(itemId: id);
        },
      ),
    ],
  );
}
