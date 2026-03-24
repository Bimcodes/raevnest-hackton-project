import 'dart:convert';
import 'package:qr_fare_crypto_core/qr_fare_crypto_core.dart';

void main() async {
  final keyPair = KeyManager.generateKeyPair();
  final pem = KeyManager.encodePublicKeyToPem(keyPair.publicKey);
  
  final payload = TransactionSigner.createSignedTripStart(
    'test_user',
    20000,
    1,
    keyPair.privateKey
  );
  
  print('---PEM---');
  print(pem);
  print('---RAW---');
  print('{"user_id":"test_user","amount":20000,"nonce":1,"timestamp":${payload.timestamp}}');
  print('---SIG---');
  print(payload.signature);
}
