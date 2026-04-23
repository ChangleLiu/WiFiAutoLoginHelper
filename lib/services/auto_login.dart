import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class AutoLogin {
  static const _storage = FlutterSecureStorage();
  static const _loginUrl = 'http://10.170.1.2:9090/zportal/login/do';

  static Future<String> checkAndLogin() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity != ConnectivityResult.wifi) return '';

      final needAuth = await _needAuthentication();
      if (!needAuth) return '';

      final username = await _storage.read(key: 'username');
      final password = await _storage.read(key: 'password');
      if (username == null || password == null || username.isEmpty) {
        return '请先设置账号密码';
      }
      return await _doLogin(username, password);
    } catch (e) {
      return '检测失败: $e';
    }
  }

  static Future<String> testLogin() async {
    final username = await _storage.read(key: 'username');
    final password = await _storage.read(key: 'password');
    if (username == null || password == null) return '请先保存账号密码';
    return await _doLogin(username, password);
  }

  static Future<bool> _needAuthentication() async {
    try {
      final response = await http
          .get(Uri.parse('http://10.170.1.2:9090/'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 302) {
        final location = response.headers['location'] ?? '';
        return location.contains('login');
      }

      final body = response.body;
      return body.contains('login') ||
          body.contains('登录') ||
          body.contains('username');
    } catch (e) {
      return true;
    }
  }

  static Future<String> _doLogin(String username, String password) async {
    try {
      final client = http.Client();

      // 访问认证服务器获取重定向
      final request = http.Request('GET', Uri.parse('http://10.170.1.2:9090/'));
      request.followRedirects = false;
      request.headers['User-Agent'] =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';

      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 10));

      String? redirectUrl;
      if (response.statusCode == 302) {
        redirectUrl = response.headers['location'];
      }

      if (redirectUrl == null) {
        return '已经在线';
      }

      // 访问登录页获取Cookie和参数
      final loginPageResponse = await client
          .get(
            Uri.parse(redirectUrl),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            },
          )
          .timeout(const Duration(seconds: 10));

      final cookies = loginPageResponse.headers['set-cookie'] ?? '';
      final jsessionid = _extractCookie(cookies, 'JSESSIONID');
      final finalUrl = loginPageResponse.request?.url.toString() ?? redirectUrl;

      // 从URL提取参数
      final uri = Uri.parse(finalUrl);
      final params = {
        'wlanuserip': uri.queryParameters['wlanuserip'] ?? '',
        'wlanacname': uri.queryParameters['wlanacname'] ?? '',
        'ssid': uri.queryParameters['ssid'] ?? '',
        'mac': uri.queryParameters['mac'] ?? '',
        'nasip': uri.queryParameters['nasip'] ?? '',
        't': uri.queryParameters['t'] ?? '',
        'url': uri.queryParameters['url'] ?? '',
      };

      // POST登录
      final loginResponse = await client
          .post(
            Uri.parse(_loginUrl),
            headers: {
              'Content-Type':
                  'application/x-www-form-urlencoded; charset=UTF-8',
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              'Referer': finalUrl,
              'X-Requested-With': 'XMLHttpRequest',
              'Origin': 'http://10.170.1.2:9090',
              'Cookie':
                  'JSESSIONID=$jsessionid; username=$username; password=$password; rememberPassword=true; failCounter=0',
            },
            body: {
              'username': username,
              'pwd': password,
              'validCodeFlag': 'false',
              ...params,
            },
          )
          .timeout(const Duration(seconds: 10));

      final body = loginResponse.body;
      if (body.contains('success') || body.contains('成功')) {
        return '自动登录成功';
      } else if (body.contains('fail') || body.contains('失败')) {
        return '登录失败：账号或密码错误';
      } else {
        return '登录结果未知';
      }
    } catch (e) {
      return '登录请求失败: $e';
    }
  }

  static String _extractCookie(String cookieHeader, String name) {
    final regex = RegExp('$name=([^;]*)');
    final match = regex.firstMatch(cookieHeader);
    return match?.group(1) ?? '';
  }
}
