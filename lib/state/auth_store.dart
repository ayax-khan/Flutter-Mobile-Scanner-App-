import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthStore extends ChangeNotifier {
  static const _keySellerId = 'auth_seller_id';
  static const _keyToken = 'auth_token';
  static const _keyEndpoint = 'auth_endpoint';

  String? sellerId;
  String? token;
  String? endpoint;

  bool get isPaired => sellerId != null && token != null && endpoint != null;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    sellerId = prefs.getString(_keySellerId);
    token = prefs.getString(_keyToken);
    endpoint = prefs.getString(_keyEndpoint);
    notifyListeners();
  }

  Future<void> savePairingData(String newSellerId, String newToken, String newEndpoint) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySellerId, newSellerId);
    await prefs.setString(_keyToken, newToken);
    await prefs.setString(_keyEndpoint, newEndpoint);
    
    sellerId = newSellerId;
    token = newToken;
    endpoint = newEndpoint;
    notifyListeners();
  }

  Future<void> unpair() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySellerId);
    await prefs.remove(_keyToken);
    await prefs.remove(_keyEndpoint);
    
    sellerId = null;
    token = null;
    endpoint = null;
    notifyListeners();
  }
}
