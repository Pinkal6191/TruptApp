import 'package:cloud_firestore/cloud_firestore.dart';

class ContractModel {
  final String id;
  final String customerId;
  final String customerName;
  final String customerAddress;
  final String customerContact;
  final DateTime createdAt;
  final double oneTimeFees;
  final double? price200ml;
  final int? moq200ml;
  final double? price500ml;
  final int? moq500ml;
  final double? price1L;
  final int? moq1L;
  final String duration;

  ContractModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerAddress,
    required this.customerContact,
    required this.createdAt,
    required this.oneTimeFees,
    this.price200ml,
    this.moq200ml,
    this.price500ml,
    this.moq500ml,
    this.price1L,
    this.moq1L,
    required this.duration,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'customerName': customerName,
      'customerAddress': customerAddress,
      'customerContact': customerContact,
      'createdAt': Timestamp.fromDate(createdAt),
      'oneTimeFees': oneTimeFees,
      'price200ml': price200ml,
      'moq200ml': moq200ml,
      'price500ml': price500ml,
      'moq500ml': moq500ml,
      'price1L': price1L,
      'moq1L': moq1L,
      'duration': duration,
    };
  }

  factory ContractModel.fromMap(Map<String, dynamic> map, String id) {
    return ContractModel(
      id: id,
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerAddress: map['customerAddress'] ?? '',
      customerContact: map['customerContact'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      oneTimeFees: (map['oneTimeFees'] ?? 0.0).toDouble(),
      price200ml: map['price200ml']?.toDouble(),
      moq200ml: map['moq200ml']?.toInt(),
      price500ml: map['price500ml']?.toDouble(),
      moq500ml: map['moq500ml']?.toInt(),
      price1L: map['price1L']?.toDouble(),
      moq1L: map['moq1L']?.toInt(),
      duration: map['duration'] ?? '',
    );
  }

  ContractModel copyWith({
    String? id,
    String? customerId,
    String? customerName,
    String? customerAddress,
    String? customerContact,
    DateTime? createdAt,
    double? oneTimeFees,
    double? price200ml,
    int? moq200ml,
    double? price500ml,
    int? moq500ml,
    double? price1L,
    int? moq1L,
    String? duration,
  }) {
    return ContractModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerAddress: customerAddress ?? this.customerAddress,
      customerContact: customerContact ?? this.customerContact,
      createdAt: createdAt ?? this.createdAt,
      oneTimeFees: oneTimeFees ?? this.oneTimeFees,
      price200ml: price200ml ?? this.price200ml,
      moq200ml: moq200ml ?? this.moq200ml,
      price500ml: price500ml ?? this.price500ml,
      moq500ml: moq500ml ?? this.moq500ml,
      price1L: price1L ?? this.price1L,
      moq1L: moq1L ?? this.moq1L,
      duration: duration ?? this.duration,
    );
  }
}
