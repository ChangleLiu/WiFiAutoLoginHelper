import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class WebViewLogin {
  static const _storage = FlutterSecureStorage();
  static WebViewController? _controller;
  static bool _loginSuccess = false;
  static BuildContext? _dialogContext;

  static Future<String> login(BuildContext context) async {
    final username = await _storage.read(key: 'username');
    final password = await _storage.read(key: 'password');

    if (username == null || password == null) {
      return '请先保存账号密码';
    }

    _loginSuccess = false;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) async {
            print('页面加载完成: $url');

            if (url.contains('loginForWeb')) {
              await Future.delayed(const Duration(milliseconds: 1000));
              await _autoFillAndSubmit(username, password);
            }
          },
          onUrlChange: (UrlChange change) {
            print('URL变化: ${change.url}');
            final url = change.url ?? '';

            if (url.contains('goToAuthResult')) {
              print('登录成功! URL: $url');
              _loginSuccess = true;
              _closeDialog();
            } else if (url.contains('fail')) {
              print('登录失败! URL: $url');
              _closeDialog();
            }
          },
          onWebResourceError: (WebResourceError error) {
            print('WebView错误: ${error.description}');
          },
        ),
      )
      ..loadRequest(
        Uri.parse('http://connectivitycheck.platform.hicloud.com/generate_204'),
      );

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        _dialogContext = dialogContext;
        return AlertDialog(
          title: const Text('正在登录...'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: WebViewWidget(controller: _controller!),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, '取消'),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );

    if (_loginSuccess) {
      return '自动登录成功';
    }

    return result ?? '登录取消';
  }

  static void _closeDialog() {
    if (_dialogContext != null && _dialogContext!.mounted) {
      Navigator.of(_dialogContext!).pop('自动登录成功');
      _dialogContext = null;
    }
  }

  static Future<void> _autoFillAndSubmit(
    String username,
    String password,
  ) async {
    final js =
        '''
      (function() {
        var userInput = document.querySelector('input[name="username"]');
        if (userInput) {
          userInput.value = '$username';
          userInput.dispatchEvent(new Event('input'));
          userInput.dispatchEvent(new Event('change'));
        }
        
        var passInput = document.querySelector('input[name="pwd"]');
        if (passInput) {
          passInput.value = '$password';
          passInput.dispatchEvent(new Event('input'));
          passInput.dispatchEvent(new Event('change'));
        }
        
        setTimeout(function() {
          var loginBtn = document.querySelector('button[type="submit"]') 
                      || document.querySelector('#login')
                      || document.querySelector('.login-btn')
                      || document.querySelector('input[type="submit"]');
          if (loginBtn) {
            loginBtn.click();
          } else {
            var form = document.querySelector('form');
            if (form) form.submit();
          }
        }, 1000);
      })();
    ''';

    await _controller?.runJavaScript(js);
  }
}
