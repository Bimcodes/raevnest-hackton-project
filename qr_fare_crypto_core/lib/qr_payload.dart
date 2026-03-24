import 'dart:convert';

class QRPayload {
  final String userId;
  final int amount; // kobo
  final int nonce;
  final int timestamp;
  final String signature; // Base64 ECDSA signature

  QRPayload({
    required this.userId,
    required this.amount,
    required this.nonce,
    required this.timestamp,
    required this.signature,
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'amount': amount,
      'nonce': nonce,
      'timestamp': timestamp,
      'signature': signature,
    };
  }

  factory QRPayload.fromJson(Map<String, dynamic> map) {
    return QRPayload(
      userId: map['user_id'] as String,
      amount: map['amount'] as int,
      nonce: map['nonce'] as int,
      timestamp: map['timestamp'] as int,
      signature: map['signature'] as String,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory QRPayload.fromJsonString(String source) =>
      QRPayload.fromJson(jsonDecode(source));
      
  /// Reconstructs the canonical string that was signed
  String get rawPayload => 
      '{"user_id":"$userId","amount":$amount,"nonce":$nonce,"timestamp":$timestamp}';
}
