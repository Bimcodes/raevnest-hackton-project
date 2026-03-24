import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:pointycastle/export.dart';
import 'qr_payload.dart';

class TransactionSigner {
  /// Signs a raw string payload using the private key and returns Base64 ECDSA
  static String signPayload(String rawPayload, ECPrivateKey privateKey) {
    final signer = Signer('SHA-256/ECDSA');
    final privParams = PrivateKeyParameter<ECPrivateKey>(privateKey);
    final secureRandom = _getSecureRandom();
    final params = ParametersWithRandom(privParams, secureRandom);
    
    signer.init(true, params);
    
    final payloadBytes = utf8.encode(rawPayload);
    final ECSignature signature = signer.generateSignature(Uint8List.fromList(payloadBytes)) as ECSignature;
    
    // Convert R and S to ASN.1 DER encoding for standardization (what Python cryptography expects)
    // Simple mock for MVP: just encode R and S as fixed length or simple string representation
    // Let's use a simple JSON format since it's an MVP and we control both sides.
    // Wait, the python side uses decoding from base64 DER.
    // To properly encode DER in Dart without extra packages, we must build the byte array manually.
    String rHex = signature.r.toRadixString(16);
    if (rHex.length % 2 != 0) rHex = '0' + rHex;
    String sHex = signature.s.toRadixString(16);
    if (sHex.length % 2 != 0) sHex = '0' + sHex;
    
    List<int> rList = _hexToBytes(rHex);
    List<int> sList = _hexToBytes(sHex);
    
    // Strict DER: Remove unnecessary leading zeros
    while (rList.length > 1 && rList[0] == 0 && (rList[1] & 0x80) == 0) {
      rList.removeAt(0);
    }
    while (sList.length > 1 && sList[0] == 0 && (sList[1] & 0x80) == 0) {
      sList.removeAt(0);
    }

    // Integer padding rule for DER
    if (rList[0] & 0x80 != 0) rList = [0x00, ...rList];
    if (sList[0] & 0x80 != 0) sList = [0x00, ...sList];
    final der = <int>[];
    der.add(0x30); // Sequence
    final len = 2 + rList.length + 2 + sList.length;
    der.add(len);
    der.add(0x02); // Integer R
    der.add(rList.length);
    der.addAll(rList);
    der.add(0x02); // Integer S
    der.add(sList.length);
    der.addAll(sList);
    
    return base64Encode(der);
  }

  /// Verifies a Base64 ECDSA signature against the raw payload
  static bool verifySignature(String rawPayload, String base64Signature, ECPublicKey publicKey) {
    final signer = Signer('SHA-256/ECDSA');
    signer.init(false, PublicKeyParameter<ECPublicKey>(publicKey));
    
    final payloadBytes = utf8.encode(rawPayload);
    final sigBytes = base64Decode(base64Signature);
    
    // Extremely basic DER parsing for MVP
    int index = 2; // skip 30 and len
    index++; // skip 02
    int rLen = sigBytes[index++];
    final r = BigInt.parse(_bytesToHex(sigBytes.sublist(index, index + rLen)), radix: 16);
    index += rLen;
    index++; // skip 02
    int sLen = sigBytes[index++];
    final s = BigInt.parse(_bytesToHex(sigBytes.sublist(index, index + sLen)), radix: 16);
    
    final ecSignature = ECSignature(r, s);
    return signer.verifySignature(Uint8List.fromList(payloadBytes), ecSignature);
  }
  
  static QRPayload createSignedTripStart(
      String userId, int maxFareKobo, int nonce, ECPrivateKey privateKey) {
    
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    final raw = '{"user_id":"$userId","amount":$maxFareKobo,"nonce":$nonce,"timestamp":$timestamp}';
    final sig = signPayload(raw, privateKey);
    
    return QRPayload(
      userId: userId, 
      amount: maxFareKobo, 
      nonce: nonce, 
      timestamp: timestamp, 
      signature: sig
    );
  }

  static SecureRandom _getSecureRandom() {
    final secureRandom = FortunaRandom();
    final random = DartRandom._random; // Dart's math Random.secure
    List<int> seeds = [];
    for (int i = 0; i < 32; i++) {
      seeds.add(random.nextInt(255));
    }
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }
  
  static List<int> _hexToBytes(String hex) {
    final result = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      result.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return result;
  }
  
  static String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
class DartRandom {
    static final math.Random _random = math.Random.secure();
    static int nextInt(int max) => _random.nextInt(max);
}
