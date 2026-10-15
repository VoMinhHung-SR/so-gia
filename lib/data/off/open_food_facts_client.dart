import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/quantity_parse.dart';
import '../db/tables.dart';

class OffProduct {
  const OffProduct({
    required this.barcode,
    this.name,
    this.brand,
    this.unitSize,
    this.unitType,
    this.imageUrl,
    this.rawQuantity,
  });

  final String barcode;
  final String? name;
  final String? brand;
  final double? unitSize;
  final UnitType? unitType;
  final String? imageUrl;
  final String? rawQuantity;
}

/// Open Food Facts lookup. Failures return null (offline / timeout / missing).
class OpenFoodFactsClient {
  OpenFoodFactsClient({
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 3),
  }) : _http = httpClient ?? http.Client();

  final http.Client _http;
  final Duration timeout;

  static const userAgent =
      'SoGia/0.1 (sổ giá thông minh; local market helper; contact: local-dev)';

  Future<OffProduct?> fetchByBarcode(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return null;

    final uri = Uri.parse(
      'https://world.openfoodfacts.org/api/v2/product/$code'
      '?fields=code,product_name,brands,quantity,image_front_small_url',
    );

    try {
      final response = await _http
          .get(uri, headers: {'User-Agent': userAgent, 'Accept': 'application/json'})
          .timeout(timeout);

      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['status'] != 1) return null;

      final product = body['product'] as Map<String, dynamic>?;
      if (product == null) return null;

      final quantity = product['quantity'] as String?;
      final parsed = parseQuantity(quantity);

      final brandRaw = product['brands'] as String?;
      final brand = brandRaw?.split(',').first.trim();

      return OffProduct(
        barcode: code,
        name: (product['product_name'] as String?)?.trim(),
        brand: (brand == null || brand.isEmpty) ? null : brand,
        unitSize: parsed?.size,
        unitType: parsed?.unitType,
        imageUrl: product['image_front_small_url'] as String?,
        rawQuantity: quantity,
      );
    } on TimeoutException {
      return null;
    } on FormatException {
      return null;
    } on http.ClientException {
      return null;
    }
  }

  void close() => _http.close();
}
