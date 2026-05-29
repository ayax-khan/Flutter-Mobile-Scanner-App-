import 'dart:convert';
import 'package:http/http.dart' as http;
import '../state/auth_store.dart';

class ApiService {
  final AuthStore authStore;

  ApiService({required this.authStore});

  Future<bool> sendScan(String trackingNumber) async {
    if (!authStore.isPaired) return false;

    try {
      final response = await http.post(
        Uri.parse(authStore.endpoint!),
        headers: {
          'Content-Type': 'application/json',
          // In a fully secure app, we would send the token as a Bearer token here
          // 'Authorization': 'Bearer ${authStore.token}',
        },
        body: jsonEncode({
          'trackingNumber': trackingNumber,
          'sellerId': authStore.sellerId,
        }),
      );

      // We consider 200 or 201 as success
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('API Error: $e');
      return false;
    }
  }
}
