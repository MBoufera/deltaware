import 'package:equatable/equatable.dart';

class Store extends Equatable {
  final String id;
  final String name;
  final String subtitle;
  final String address;
  final String wilaya;
  final String phone;
  final String nif;
  final String nis;
  final String rc;
  final String ai;
  final String? logoUrl;
  final bool enableTimbre;
  final bool isActive;
  final DateTime createdAt;
  final int memberCount;
  final String myRole; // 'super_admin' | 'admin' | 'worker'

  const Store({
    required this.id,
    required this.name,
    this.subtitle = 'Vente en Gros et Détail',
    this.address = '',
    this.wilaya = '',
    this.phone = '',
    this.nif = '',
    this.nis = '',
    this.rc = '',
    this.ai = '',
    this.logoUrl,
    this.enableTimbre = false,
    this.isActive = true,
    required this.createdAt,
    this.memberCount = 0,
    this.myRole = 'worker',
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id:           json['id'] as String,
      name:         (json['name'] as String?) ?? 'Store',
      subtitle:     (json['subtitle'] as String?) ?? '',
      address:      (json['address'] as String?) ?? '',
      wilaya:       (json['wilaya'] as String?) ?? '',
      phone:        (json['phone'] as String?) ?? '',
      nif:          (json['nif'] as String?) ?? '',
      nis:          (json['nis'] as String?) ?? '',
      rc:           (json['rc'] as String?) ?? '',
      ai:           (json['ai'] as String?) ?? '',
      logoUrl:      json['logo_url'] as String?,
      enableTimbre: (json['enable_timbre'] as bool?) ?? false,
      isActive:     (json['is_active'] as bool?) ?? true,
      createdAt:    DateTime.parse((json['created_at'] as String?) ?? DateTime.now().toIso8601String()),
      memberCount:  (json['member_count'] as int?) ?? 0,
      myRole:       (json['my_role'] as String?) ?? 'worker',
    );
  }

  Map<String, dynamic> toJson() => {
    'id':             id,
    'name':           name,
    'subtitle':       subtitle,
    'address':        address,
    'wilaya':         wilaya,
    'phone':          phone,
    'nif':            nif,
    'nis':            nis,
    'rc':             rc,
    'ai':             ai,
    'logo_url':       logoUrl,
    'enable_timbre':  enableTimbre,
    'is_active':      isActive,
    'created_at':     createdAt.toIso8601String(),
    'member_count':   memberCount,
    'my_role':        myRole,
  };

  bool get isAdmin => myRole == 'admin' || myRole == 'super_admin';

  Store copyWith({
    String? id,
    String? name,
    String? subtitle,
    String? address,
    String? wilaya,
    String? phone,
    String? nif,
    String? nis,
    String? rc,
    String? ai,
    String? logoUrl,
    bool? enableTimbre,
    bool? isActive,
    DateTime? createdAt,
    int? memberCount,
    String? myRole,
  }) {
    return Store(
      id:           id ?? this.id,
      name:         name ?? this.name,
      subtitle:     subtitle ?? this.subtitle,
      address:      address ?? this.address,
      wilaya:       wilaya ?? this.wilaya,
      phone:        phone ?? this.phone,
      nif:          nif ?? this.nif,
      nis:          nis ?? this.nis,
      rc:           rc ?? this.rc,
      ai:           ai ?? this.ai,
      logoUrl:      logoUrl ?? this.logoUrl,
      enableTimbre: enableTimbre ?? this.enableTimbre,
      isActive:     isActive ?? this.isActive,
      createdAt:    createdAt ?? this.createdAt,
      memberCount:  memberCount ?? this.memberCount,
      myRole:       myRole ?? this.myRole,
    );
  }

  @override
  List<Object?> get props => [id, name, subtitle, address, wilaya, phone, nif, nis, rc, ai,
      logoUrl, enableTimbre, isActive, createdAt, memberCount, myRole];
}
