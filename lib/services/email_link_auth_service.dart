import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class EmailOtpAuthService {
  EmailOtpAuthService._();

  static final EmailOtpAuthService instance = EmailOtpAuthService._();

  static const String _emailJsServiceId = String.fromEnvironment('EMAILJS_SERVICE_ID', defaultValue: '');
  static const String _emailJsTemplateId = String.fromEnvironment('EMAILJS_TEMPLATE_ID', defaultValue: '');
  static const String _emailJsPublicKey = String.fromEnvironment('EMAILJS_PUBLIC_KEY', defaultValue: '');

  static const Duration _otpValidity = Duration(minutes: 5);
  static const bool _bypassOtpFromEnv = bool.fromEnvironment('BYPASS_OTP', defaultValue: false);
  static const String _debugBypassCode = '0000';
  final Random _random = Random();

  static final Map<String, _OtpSession> _otpStore = <String, _OtpSession>{};

  bool get _isOtpBypassEnabled => !kReleaseMode && _bypassOtpFromEnv;

  Future<void> sendOtp({required String email}) async {
    if (_isOtpBypassEnabled) {
      _otpStore[email.toLowerCase()] = _OtpSession(
        code: _debugBypassCode,
        expiresAt: DateTime.now().add(_otpValidity),
      );
      return;
    }

    if (_emailJsServiceId.isEmpty || _emailJsTemplateId.isEmpty || _emailJsPublicKey.isEmpty) {
      throw StateError(
        'Email OTP is not configured yet. Please add valid EmailJS credentials.',
      );
    }

    final otp = _generateOtp();
    _otpStore[email.toLowerCase()] = _OtpSession(
      code: otp,
      expiresAt: DateTime.now().add(_otpValidity),
    );

    final response = await http.post(
      Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
      headers: <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(<String, dynamic>{
        'service_id': _emailJsServiceId,
        'template_id': _emailJsTemplateId,
        'user_id': _emailJsPublicKey,
        'template_params': <String, dynamic>{
          'to_email': email,
          'otp': otp,
        },
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = response.body;
      if (response.statusCode == 403 && body.contains('non-browser environments')) {
        throw Exception(
          'Email service blocked this request. In EmailJS, enable "API access from non-browser environments" under Account Security.',
        );
      }
      if (response.statusCode == 403 && body.contains('strict mode') && body.contains('Private Key')) {
        throw Exception(
          'EmailJS strict mode is enabled. Disable strict mode in EmailJS Account Security, or move OTP sending to a backend that can safely use a private key.',
        );
      }
      throw Exception('Unable to send OTP email. (${response.statusCode}) $body');
    }
  }

  bool verifyOtp({required String email, required String otp}) {
    if (_isOtpBypassEnabled) {
      return otp == _debugBypassCode;
    }

    final key = email.toLowerCase();
    final session = _otpStore[key];

    if (session == null) {
      return false;
    }

    if (DateTime.now().isAfter(session.expiresAt)) {
      _otpStore.remove(key);
      return false;
    }

    if (session.code != otp) {
      return false;
    }

    _otpStore.remove(key);
    return true;
  }

  String _generateOtp() {
    final value = _random.nextInt(10000);
    return value.toString().padLeft(4, '0');
  }
}

class _OtpSession {
  const _OtpSession({
    required this.code,
    required this.expiresAt,
  });

  final String code;
  final DateTime expiresAt;
}
