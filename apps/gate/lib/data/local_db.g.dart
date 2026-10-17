// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_db.dart';

// ignore_for_file: type=lint
class $DeviceSettingsTable extends DeviceSettings
    with TableInfo<$DeviceSettingsTable, DeviceSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeviceSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'device_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeviceSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  DeviceSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeviceSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $DeviceSettingsTable createAlias(String alias) {
    return $DeviceSettingsTable(attachedDatabase, alias);
  }
}

class DeviceSetting extends DataClass implements Insertable<DeviceSetting> {
  final String key;
  final String value;
  const DeviceSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  DeviceSettingsCompanion toCompanion(bool nullToAbsent) {
    return DeviceSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory DeviceSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeviceSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  DeviceSetting copyWith({String? key, String? value}) =>
      DeviceSetting(key: key ?? this.key, value: value ?? this.value);
  DeviceSetting copyWithCompanion(DeviceSettingsCompanion data) {
    return DeviceSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeviceSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeviceSetting &&
          other.key == this.key &&
          other.value == this.value);
}

class DeviceSettingsCompanion extends UpdateCompanion<DeviceSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const DeviceSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeviceSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<DeviceSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeviceSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return DeviceSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeviceSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedPassesTable extends CachedPasses
    with TableInfo<$CachedPassesTable, CachedPassesData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedPassesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tokenHashMeta = const VerificationMeta(
    'tokenHash',
  );
  @override
  late final GeneratedColumn<String> tokenHash = GeneratedColumn<String>(
    'token_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _passIdMeta = const VerificationMeta('passId');
  @override
  late final GeneratedColumn<String> passId = GeneratedColumn<String>(
    'pass_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fullNameMeta = const VerificationMeta(
    'fullName',
  );
  @override
  late final GeneratedColumn<String> fullName = GeneratedColumn<String>(
    'full_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _passTypeMeta = const VerificationMeta(
    'passType',
  );
  @override
  late final GeneratedColumn<String> passType = GeneratedColumn<String>(
    'pass_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plateMeta = const VerificationMeta('plate');
  @override
  late final GeneratedColumn<String> plate = GeneratedColumn<String>(
    'plate',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _validFromMeta = const VerificationMeta(
    'validFrom',
  );
  @override
  late final GeneratedColumn<DateTime> validFrom = GeneratedColumn<DateTime>(
    'valid_from',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _validUntilMeta = const VerificationMeta(
    'validUntil',
  );
  @override
  late final GeneratedColumn<DateTime> validUntil = GeneratedColumn<DateTime>(
    'valid_until',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    tokenHash,
    passId,
    fullName,
    passType,
    plate,
    validFrom,
    validUntil,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_passes';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedPassesData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('token_hash')) {
      context.handle(
        _tokenHashMeta,
        tokenHash.isAcceptableOrUnknown(data['token_hash']!, _tokenHashMeta),
      );
    } else if (isInserting) {
      context.missing(_tokenHashMeta);
    }
    if (data.containsKey('pass_id')) {
      context.handle(
        _passIdMeta,
        passId.isAcceptableOrUnknown(data['pass_id']!, _passIdMeta),
      );
    } else if (isInserting) {
      context.missing(_passIdMeta);
    }
    if (data.containsKey('full_name')) {
      context.handle(
        _fullNameMeta,
        fullName.isAcceptableOrUnknown(data['full_name']!, _fullNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fullNameMeta);
    }
    if (data.containsKey('pass_type')) {
      context.handle(
        _passTypeMeta,
        passType.isAcceptableOrUnknown(data['pass_type']!, _passTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_passTypeMeta);
    }
    if (data.containsKey('plate')) {
      context.handle(
        _plateMeta,
        plate.isAcceptableOrUnknown(data['plate']!, _plateMeta),
      );
    }
    if (data.containsKey('valid_from')) {
      context.handle(
        _validFromMeta,
        validFrom.isAcceptableOrUnknown(data['valid_from']!, _validFromMeta),
      );
    } else if (isInserting) {
      context.missing(_validFromMeta);
    }
    if (data.containsKey('valid_until')) {
      context.handle(
        _validUntilMeta,
        validUntil.isAcceptableOrUnknown(data['valid_until']!, _validUntilMeta),
      );
    } else if (isInserting) {
      context.missing(_validUntilMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tokenHash};
  @override
  CachedPassesData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedPassesData(
      tokenHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}token_hash'],
      )!,
      passId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pass_id'],
      )!,
      fullName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}full_name'],
      )!,
      passType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pass_type'],
      )!,
      plate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plate'],
      ),
      validFrom: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}valid_from'],
      )!,
      validUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}valid_until'],
      )!,
    );
  }

  @override
  $CachedPassesTable createAlias(String alias) {
    return $CachedPassesTable(attachedDatabase, alias);
  }
}

class CachedPassesData extends DataClass
    implements Insertable<CachedPassesData> {
  final String tokenHash;
  final String passId;
  final String fullName;
  final String passType;
  final String? plate;
  final DateTime validFrom;
  final DateTime validUntil;
  const CachedPassesData({
    required this.tokenHash,
    required this.passId,
    required this.fullName,
    required this.passType,
    this.plate,
    required this.validFrom,
    required this.validUntil,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['token_hash'] = Variable<String>(tokenHash);
    map['pass_id'] = Variable<String>(passId);
    map['full_name'] = Variable<String>(fullName);
    map['pass_type'] = Variable<String>(passType);
    if (!nullToAbsent || plate != null) {
      map['plate'] = Variable<String>(plate);
    }
    map['valid_from'] = Variable<DateTime>(validFrom);
    map['valid_until'] = Variable<DateTime>(validUntil);
    return map;
  }

  CachedPassesCompanion toCompanion(bool nullToAbsent) {
    return CachedPassesCompanion(
      tokenHash: Value(tokenHash),
      passId: Value(passId),
      fullName: Value(fullName),
      passType: Value(passType),
      plate: plate == null && nullToAbsent
          ? const Value.absent()
          : Value(plate),
      validFrom: Value(validFrom),
      validUntil: Value(validUntil),
    );
  }

  factory CachedPassesData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedPassesData(
      tokenHash: serializer.fromJson<String>(json['tokenHash']),
      passId: serializer.fromJson<String>(json['passId']),
      fullName: serializer.fromJson<String>(json['fullName']),
      passType: serializer.fromJson<String>(json['passType']),
      plate: serializer.fromJson<String?>(json['plate']),
      validFrom: serializer.fromJson<DateTime>(json['validFrom']),
      validUntil: serializer.fromJson<DateTime>(json['validUntil']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tokenHash': serializer.toJson<String>(tokenHash),
      'passId': serializer.toJson<String>(passId),
      'fullName': serializer.toJson<String>(fullName),
      'passType': serializer.toJson<String>(passType),
      'plate': serializer.toJson<String?>(plate),
      'validFrom': serializer.toJson<DateTime>(validFrom),
      'validUntil': serializer.toJson<DateTime>(validUntil),
    };
  }

  CachedPassesData copyWith({
    String? tokenHash,
    String? passId,
    String? fullName,
    String? passType,
    Value<String?> plate = const Value.absent(),
    DateTime? validFrom,
    DateTime? validUntil,
  }) => CachedPassesData(
    tokenHash: tokenHash ?? this.tokenHash,
    passId: passId ?? this.passId,
    fullName: fullName ?? this.fullName,
    passType: passType ?? this.passType,
    plate: plate.present ? plate.value : this.plate,
    validFrom: validFrom ?? this.validFrom,
    validUntil: validUntil ?? this.validUntil,
  );
  CachedPassesData copyWithCompanion(CachedPassesCompanion data) {
    return CachedPassesData(
      tokenHash: data.tokenHash.present ? data.tokenHash.value : this.tokenHash,
      passId: data.passId.present ? data.passId.value : this.passId,
      fullName: data.fullName.present ? data.fullName.value : this.fullName,
      passType: data.passType.present ? data.passType.value : this.passType,
      plate: data.plate.present ? data.plate.value : this.plate,
      validFrom: data.validFrom.present ? data.validFrom.value : this.validFrom,
      validUntil: data.validUntil.present
          ? data.validUntil.value
          : this.validUntil,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedPassesData(')
          ..write('tokenHash: $tokenHash, ')
          ..write('passId: $passId, ')
          ..write('fullName: $fullName, ')
          ..write('passType: $passType, ')
          ..write('plate: $plate, ')
          ..write('validFrom: $validFrom, ')
          ..write('validUntil: $validUntil')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    tokenHash,
    passId,
    fullName,
    passType,
    plate,
    validFrom,
    validUntil,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedPassesData &&
          other.tokenHash == this.tokenHash &&
          other.passId == this.passId &&
          other.fullName == this.fullName &&
          other.passType == this.passType &&
          other.plate == this.plate &&
          other.validFrom == this.validFrom &&
          other.validUntil == this.validUntil);
}

class CachedPassesCompanion extends UpdateCompanion<CachedPassesData> {
  final Value<String> tokenHash;
  final Value<String> passId;
  final Value<String> fullName;
  final Value<String> passType;
  final Value<String?> plate;
  final Value<DateTime> validFrom;
  final Value<DateTime> validUntil;
  final Value<int> rowid;
  const CachedPassesCompanion({
    this.tokenHash = const Value.absent(),
    this.passId = const Value.absent(),
    this.fullName = const Value.absent(),
    this.passType = const Value.absent(),
    this.plate = const Value.absent(),
    this.validFrom = const Value.absent(),
    this.validUntil = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedPassesCompanion.insert({
    required String tokenHash,
    required String passId,
    required String fullName,
    required String passType,
    this.plate = const Value.absent(),
    required DateTime validFrom,
    required DateTime validUntil,
    this.rowid = const Value.absent(),
  }) : tokenHash = Value(tokenHash),
       passId = Value(passId),
       fullName = Value(fullName),
       passType = Value(passType),
       validFrom = Value(validFrom),
       validUntil = Value(validUntil);
  static Insertable<CachedPassesData> custom({
    Expression<String>? tokenHash,
    Expression<String>? passId,
    Expression<String>? fullName,
    Expression<String>? passType,
    Expression<String>? plate,
    Expression<DateTime>? validFrom,
    Expression<DateTime>? validUntil,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tokenHash != null) 'token_hash': tokenHash,
      if (passId != null) 'pass_id': passId,
      if (fullName != null) 'full_name': fullName,
      if (passType != null) 'pass_type': passType,
      if (plate != null) 'plate': plate,
      if (validFrom != null) 'valid_from': validFrom,
      if (validUntil != null) 'valid_until': validUntil,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedPassesCompanion copyWith({
    Value<String>? tokenHash,
    Value<String>? passId,
    Value<String>? fullName,
    Value<String>? passType,
    Value<String?>? plate,
    Value<DateTime>? validFrom,
    Value<DateTime>? validUntil,
    Value<int>? rowid,
  }) {
    return CachedPassesCompanion(
      tokenHash: tokenHash ?? this.tokenHash,
      passId: passId ?? this.passId,
      fullName: fullName ?? this.fullName,
      passType: passType ?? this.passType,
      plate: plate ?? this.plate,
      validFrom: validFrom ?? this.validFrom,
      validUntil: validUntil ?? this.validUntil,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tokenHash.present) {
      map['token_hash'] = Variable<String>(tokenHash.value);
    }
    if (passId.present) {
      map['pass_id'] = Variable<String>(passId.value);
    }
    if (fullName.present) {
      map['full_name'] = Variable<String>(fullName.value);
    }
    if (passType.present) {
      map['pass_type'] = Variable<String>(passType.value);
    }
    if (plate.present) {
      map['plate'] = Variable<String>(plate.value);
    }
    if (validFrom.present) {
      map['valid_from'] = Variable<DateTime>(validFrom.value);
    }
    if (validUntil.present) {
      map['valid_until'] = Variable<DateTime>(validUntil.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedPassesCompanion(')
          ..write('tokenHash: $tokenHash, ')
          ..write('passId: $passId, ')
          ..write('fullName: $fullName, ')
          ..write('passType: $passType, ')
          ..write('plate: $plate, ')
          ..write('validFrom: $validFrom, ')
          ..write('validUntil: $validUntil, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalOpenVisitsTable extends LocalOpenVisits
    with TableInfo<$LocalOpenVisitsTable, LocalOpenVisit> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalOpenVisitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _passIdMeta = const VerificationMeta('passId');
  @override
  late final GeneratedColumn<String> passId = GeneratedColumn<String>(
    'pass_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entryAtMeta = const VerificationMeta(
    'entryAt',
  );
  @override
  late final GeneratedColumn<DateTime> entryAt = GeneratedColumn<DateTime>(
    'entry_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [passId, entryAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_open_visits';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalOpenVisit> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('pass_id')) {
      context.handle(
        _passIdMeta,
        passId.isAcceptableOrUnknown(data['pass_id']!, _passIdMeta),
      );
    } else if (isInserting) {
      context.missing(_passIdMeta);
    }
    if (data.containsKey('entry_at')) {
      context.handle(
        _entryAtMeta,
        entryAt.isAcceptableOrUnknown(data['entry_at']!, _entryAtMeta),
      );
    } else if (isInserting) {
      context.missing(_entryAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {passId};
  @override
  LocalOpenVisit map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalOpenVisit(
      passId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pass_id'],
      )!,
      entryAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}entry_at'],
      )!,
    );
  }

  @override
  $LocalOpenVisitsTable createAlias(String alias) {
    return $LocalOpenVisitsTable(attachedDatabase, alias);
  }
}

class LocalOpenVisit extends DataClass implements Insertable<LocalOpenVisit> {
  final String passId;
  final DateTime entryAt;
  const LocalOpenVisit({required this.passId, required this.entryAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['pass_id'] = Variable<String>(passId);
    map['entry_at'] = Variable<DateTime>(entryAt);
    return map;
  }

  LocalOpenVisitsCompanion toCompanion(bool nullToAbsent) {
    return LocalOpenVisitsCompanion(
      passId: Value(passId),
      entryAt: Value(entryAt),
    );
  }

  factory LocalOpenVisit.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalOpenVisit(
      passId: serializer.fromJson<String>(json['passId']),
      entryAt: serializer.fromJson<DateTime>(json['entryAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'passId': serializer.toJson<String>(passId),
      'entryAt': serializer.toJson<DateTime>(entryAt),
    };
  }

  LocalOpenVisit copyWith({String? passId, DateTime? entryAt}) =>
      LocalOpenVisit(
        passId: passId ?? this.passId,
        entryAt: entryAt ?? this.entryAt,
      );
  LocalOpenVisit copyWithCompanion(LocalOpenVisitsCompanion data) {
    return LocalOpenVisit(
      passId: data.passId.present ? data.passId.value : this.passId,
      entryAt: data.entryAt.present ? data.entryAt.value : this.entryAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalOpenVisit(')
          ..write('passId: $passId, ')
          ..write('entryAt: $entryAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(passId, entryAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalOpenVisit &&
          other.passId == this.passId &&
          other.entryAt == this.entryAt);
}

class LocalOpenVisitsCompanion extends UpdateCompanion<LocalOpenVisit> {
  final Value<String> passId;
  final Value<DateTime> entryAt;
  final Value<int> rowid;
  const LocalOpenVisitsCompanion({
    this.passId = const Value.absent(),
    this.entryAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalOpenVisitsCompanion.insert({
    required String passId,
    required DateTime entryAt,
    this.rowid = const Value.absent(),
  }) : passId = Value(passId),
       entryAt = Value(entryAt);
  static Insertable<LocalOpenVisit> custom({
    Expression<String>? passId,
    Expression<DateTime>? entryAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (passId != null) 'pass_id': passId,
      if (entryAt != null) 'entry_at': entryAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalOpenVisitsCompanion copyWith({
    Value<String>? passId,
    Value<DateTime>? entryAt,
    Value<int>? rowid,
  }) {
    return LocalOpenVisitsCompanion(
      passId: passId ?? this.passId,
      entryAt: entryAt ?? this.entryAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (passId.present) {
      map['pass_id'] = Variable<String>(passId.value);
    }
    if (entryAt.present) {
      map['entry_at'] = Variable<DateTime>(entryAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalOpenVisitsCompanion(')
          ..write('passId: $passId, ')
          ..write('entryAt: $entryAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _photoMeta = const VerificationMeta('photo');
  @override
  late final GeneratedColumn<Uint8List> photo = GeneratedColumn<Uint8List>(
    'photo',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _failedMeta = const VerificationMeta('failed');
  @override
  late final GeneratedColumn<bool> failed = GeneratedColumn<bool>(
    'failed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("failed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    eventId,
    payload,
    photo,
    createdAt,
    attempts,
    lastError,
    failed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('photo')) {
      context.handle(
        _photoMeta,
        photo.isAcceptableOrUnknown(data['photo']!, _photoMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('failed')) {
      context.handle(
        _failedMeta,
        failed.isAcceptableOrUnknown(data['failed']!, _failedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      photo: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}photo'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      failed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}failed'],
      )!,
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxData extends DataClass implements Insertable<OutboxData> {
  final int id;
  final String kind;
  final String eventId;
  final String payload;
  final Uint8List? photo;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;

  /// Refused by the server for a reason a retry will not fix; kept for review.
  final bool failed;
  const OutboxData({
    required this.id,
    required this.kind,
    required this.eventId,
    required this.payload,
    this.photo,
    required this.createdAt,
    required this.attempts,
    this.lastError,
    required this.failed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['kind'] = Variable<String>(kind);
    map['event_id'] = Variable<String>(eventId);
    map['payload'] = Variable<String>(payload);
    if (!nullToAbsent || photo != null) {
      map['photo'] = Variable<Uint8List>(photo);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['failed'] = Variable<bool>(failed);
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      id: Value(id),
      kind: Value(kind),
      eventId: Value(eventId),
      payload: Value(payload),
      photo: photo == null && nullToAbsent
          ? const Value.absent()
          : Value(photo),
      createdAt: Value(createdAt),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      failed: Value(failed),
    );
  }

  factory OutboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxData(
      id: serializer.fromJson<int>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      eventId: serializer.fromJson<String>(json['eventId']),
      payload: serializer.fromJson<String>(json['payload']),
      photo: serializer.fromJson<Uint8List?>(json['photo']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      failed: serializer.fromJson<bool>(json['failed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'kind': serializer.toJson<String>(kind),
      'eventId': serializer.toJson<String>(eventId),
      'payload': serializer.toJson<String>(payload),
      'photo': serializer.toJson<Uint8List?>(photo),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
      'failed': serializer.toJson<bool>(failed),
    };
  }

  OutboxData copyWith({
    int? id,
    String? kind,
    String? eventId,
    String? payload,
    Value<Uint8List?> photo = const Value.absent(),
    DateTime? createdAt,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
    bool? failed,
  }) => OutboxData(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    eventId: eventId ?? this.eventId,
    payload: payload ?? this.payload,
    photo: photo.present ? photo.value : this.photo,
    createdAt: createdAt ?? this.createdAt,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
    failed: failed ?? this.failed,
  );
  OutboxData copyWithCompanion(OutboxCompanion data) {
    return OutboxData(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      payload: data.payload.present ? data.payload.value : this.payload,
      photo: data.photo.present ? data.photo.value : this.photo,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      failed: data.failed.present ? data.failed.value : this.failed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxData(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('eventId: $eventId, ')
          ..write('payload: $payload, ')
          ..write('photo: $photo, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('failed: $failed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    eventId,
    payload,
    $driftBlobEquality.hash(photo),
    createdAt,
    attempts,
    lastError,
    failed,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxData &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.eventId == this.eventId &&
          other.payload == this.payload &&
          $driftBlobEquality.equals(other.photo, this.photo) &&
          other.createdAt == this.createdAt &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError &&
          other.failed == this.failed);
}

class OutboxCompanion extends UpdateCompanion<OutboxData> {
  final Value<int> id;
  final Value<String> kind;
  final Value<String> eventId;
  final Value<String> payload;
  final Value<Uint8List?> photo;
  final Value<DateTime> createdAt;
  final Value<int> attempts;
  final Value<String?> lastError;
  final Value<bool> failed;
  const OutboxCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.eventId = const Value.absent(),
    this.payload = const Value.absent(),
    this.photo = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.failed = const Value.absent(),
  });
  OutboxCompanion.insert({
    this.id = const Value.absent(),
    required String kind,
    required String eventId,
    required String payload,
    this.photo = const Value.absent(),
    required DateTime createdAt,
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.failed = const Value.absent(),
  }) : kind = Value(kind),
       eventId = Value(eventId),
       payload = Value(payload),
       createdAt = Value(createdAt);
  static Insertable<OutboxData> custom({
    Expression<int>? id,
    Expression<String>? kind,
    Expression<String>? eventId,
    Expression<String>? payload,
    Expression<Uint8List>? photo,
    Expression<DateTime>? createdAt,
    Expression<int>? attempts,
    Expression<String>? lastError,
    Expression<bool>? failed,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (eventId != null) 'event_id': eventId,
      if (payload != null) 'payload': payload,
      if (photo != null) 'photo': photo,
      if (createdAt != null) 'created_at': createdAt,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
      if (failed != null) 'failed': failed,
    });
  }

  OutboxCompanion copyWith({
    Value<int>? id,
    Value<String>? kind,
    Value<String>? eventId,
    Value<String>? payload,
    Value<Uint8List?>? photo,
    Value<DateTime>? createdAt,
    Value<int>? attempts,
    Value<String?>? lastError,
    Value<bool>? failed,
  }) {
    return OutboxCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      eventId: eventId ?? this.eventId,
      payload: payload ?? this.payload,
      photo: photo ?? this.photo,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      failed: failed ?? this.failed,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (photo.present) {
      map['photo'] = Variable<Uint8List>(photo.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (failed.present) {
      map['failed'] = Variable<bool>(failed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('eventId: $eventId, ')
          ..write('payload: $payload, ')
          ..write('photo: $photo, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('failed: $failed')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocalDb extends GeneratedDatabase {
  _$LocalDb(QueryExecutor e) : super(e);
  $LocalDbManager get managers => $LocalDbManager(this);
  late final $DeviceSettingsTable deviceSettings = $DeviceSettingsTable(this);
  late final $CachedPassesTable cachedPasses = $CachedPassesTable(this);
  late final $LocalOpenVisitsTable localOpenVisits = $LocalOpenVisitsTable(
    this,
  );
  late final $OutboxTable outbox = $OutboxTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    deviceSettings,
    cachedPasses,
    localOpenVisits,
    outbox,
  ];
}

typedef $$DeviceSettingsTableCreateCompanionBuilder =
    DeviceSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$DeviceSettingsTableUpdateCompanionBuilder =
    DeviceSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$DeviceSettingsTableFilterComposer
    extends Composer<_$LocalDb, $DeviceSettingsTable> {
  $$DeviceSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DeviceSettingsTableOrderingComposer
    extends Composer<_$LocalDb, $DeviceSettingsTable> {
  $$DeviceSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DeviceSettingsTableAnnotationComposer
    extends Composer<_$LocalDb, $DeviceSettingsTable> {
  $$DeviceSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$DeviceSettingsTableTableManager
    extends
        RootTableManager<
          _$LocalDb,
          $DeviceSettingsTable,
          DeviceSetting,
          $$DeviceSettingsTableFilterComposer,
          $$DeviceSettingsTableOrderingComposer,
          $$DeviceSettingsTableAnnotationComposer,
          $$DeviceSettingsTableCreateCompanionBuilder,
          $$DeviceSettingsTableUpdateCompanionBuilder,
          (
            DeviceSetting,
            BaseReferences<_$LocalDb, $DeviceSettingsTable, DeviceSetting>,
          ),
          DeviceSetting,
          PrefetchHooks Function()
        > {
  $$DeviceSettingsTableTableManager(_$LocalDb db, $DeviceSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeviceSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeviceSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeviceSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) =>
                  DeviceSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => DeviceSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DeviceSettingsTable, DeviceSetting>(table),
                  BaseReferences<
                    _$LocalDb,
                    $DeviceSettingsTable,
                    DeviceSetting
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DeviceSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDb,
      $DeviceSettingsTable,
      DeviceSetting,
      $$DeviceSettingsTableFilterComposer,
      $$DeviceSettingsTableOrderingComposer,
      $$DeviceSettingsTableAnnotationComposer,
      $$DeviceSettingsTableCreateCompanionBuilder,
      $$DeviceSettingsTableUpdateCompanionBuilder,
      (
        DeviceSetting,
        BaseReferences<_$LocalDb, $DeviceSettingsTable, DeviceSetting>,
      ),
      DeviceSetting,
      PrefetchHooks Function()
    >;
typedef $$CachedPassesTableCreateCompanionBuilder =
    CachedPassesCompanion Function({
      required String tokenHash,
      required String passId,
      required String fullName,
      required String passType,
      Value<String?> plate,
      required DateTime validFrom,
      required DateTime validUntil,
      Value<int> rowid,
    });
typedef $$CachedPassesTableUpdateCompanionBuilder =
    CachedPassesCompanion Function({
      Value<String> tokenHash,
      Value<String> passId,
      Value<String> fullName,
      Value<String> passType,
      Value<String?> plate,
      Value<DateTime> validFrom,
      Value<DateTime> validUntil,
      Value<int> rowid,
    });

class $$CachedPassesTableFilterComposer
    extends Composer<_$LocalDb, $CachedPassesTable> {
  $$CachedPassesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tokenHash => $composableBuilder(
    column: $table.tokenHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get passId => $composableBuilder(
    column: $table.passId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fullName => $composableBuilder(
    column: $table.fullName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get passType => $composableBuilder(
    column: $table.passType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plate => $composableBuilder(
    column: $table.plate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get validFrom => $composableBuilder(
    column: $table.validFrom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get validUntil => $composableBuilder(
    column: $table.validUntil,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedPassesTableOrderingComposer
    extends Composer<_$LocalDb, $CachedPassesTable> {
  $$CachedPassesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tokenHash => $composableBuilder(
    column: $table.tokenHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get passId => $composableBuilder(
    column: $table.passId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fullName => $composableBuilder(
    column: $table.fullName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get passType => $composableBuilder(
    column: $table.passType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plate => $composableBuilder(
    column: $table.plate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get validFrom => $composableBuilder(
    column: $table.validFrom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get validUntil => $composableBuilder(
    column: $table.validUntil,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedPassesTableAnnotationComposer
    extends Composer<_$LocalDb, $CachedPassesTable> {
  $$CachedPassesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tokenHash =>
      $composableBuilder(column: $table.tokenHash, builder: (column) => column);

  GeneratedColumn<String> get passId =>
      $composableBuilder(column: $table.passId, builder: (column) => column);

  GeneratedColumn<String> get fullName =>
      $composableBuilder(column: $table.fullName, builder: (column) => column);

  GeneratedColumn<String> get passType =>
      $composableBuilder(column: $table.passType, builder: (column) => column);

  GeneratedColumn<String> get plate =>
      $composableBuilder(column: $table.plate, builder: (column) => column);

  GeneratedColumn<DateTime> get validFrom =>
      $composableBuilder(column: $table.validFrom, builder: (column) => column);

  GeneratedColumn<DateTime> get validUntil => $composableBuilder(
    column: $table.validUntil,
    builder: (column) => column,
  );
}

class $$CachedPassesTableTableManager
    extends
        RootTableManager<
          _$LocalDb,
          $CachedPassesTable,
          CachedPassesData,
          $$CachedPassesTableFilterComposer,
          $$CachedPassesTableOrderingComposer,
          $$CachedPassesTableAnnotationComposer,
          $$CachedPassesTableCreateCompanionBuilder,
          $$CachedPassesTableUpdateCompanionBuilder,
          (
            CachedPassesData,
            BaseReferences<_$LocalDb, $CachedPassesTable, CachedPassesData>,
          ),
          CachedPassesData,
          PrefetchHooks Function()
        > {
  $$CachedPassesTableTableManager(_$LocalDb db, $CachedPassesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedPassesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedPassesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedPassesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> tokenHash = const Value.absent(),
                Value<String> passId = const Value.absent(),
                Value<String> fullName = const Value.absent(),
                Value<String> passType = const Value.absent(),
                Value<String?> plate = const Value.absent(),
                Value<DateTime> validFrom = const Value.absent(),
                Value<DateTime> validUntil = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedPassesCompanion(
                tokenHash: tokenHash,
                passId: passId,
                fullName: fullName,
                passType: passType,
                plate: plate,
                validFrom: validFrom,
                validUntil: validUntil,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String tokenHash,
                required String passId,
                required String fullName,
                required String passType,
                Value<String?> plate = const Value.absent(),
                required DateTime validFrom,
                required DateTime validUntil,
                Value<int> rowid = const Value.absent(),
              }) => CachedPassesCompanion.insert(
                tokenHash: tokenHash,
                passId: passId,
                fullName: fullName,
                passType: passType,
                plate: plate,
                validFrom: validFrom,
                validUntil: validUntil,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedPassesTable, CachedPassesData>(table),
                  BaseReferences<
                    _$LocalDb,
                    $CachedPassesTable,
                    CachedPassesData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedPassesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDb,
      $CachedPassesTable,
      CachedPassesData,
      $$CachedPassesTableFilterComposer,
      $$CachedPassesTableOrderingComposer,
      $$CachedPassesTableAnnotationComposer,
      $$CachedPassesTableCreateCompanionBuilder,
      $$CachedPassesTableUpdateCompanionBuilder,
      (
        CachedPassesData,
        BaseReferences<_$LocalDb, $CachedPassesTable, CachedPassesData>,
      ),
      CachedPassesData,
      PrefetchHooks Function()
    >;
typedef $$LocalOpenVisitsTableCreateCompanionBuilder =
    LocalOpenVisitsCompanion Function({
      required String passId,
      required DateTime entryAt,
      Value<int> rowid,
    });
typedef $$LocalOpenVisitsTableUpdateCompanionBuilder =
    LocalOpenVisitsCompanion Function({
      Value<String> passId,
      Value<DateTime> entryAt,
      Value<int> rowid,
    });

class $$LocalOpenVisitsTableFilterComposer
    extends Composer<_$LocalDb, $LocalOpenVisitsTable> {
  $$LocalOpenVisitsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get passId => $composableBuilder(
    column: $table.passId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get entryAt => $composableBuilder(
    column: $table.entryAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalOpenVisitsTableOrderingComposer
    extends Composer<_$LocalDb, $LocalOpenVisitsTable> {
  $$LocalOpenVisitsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get passId => $composableBuilder(
    column: $table.passId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get entryAt => $composableBuilder(
    column: $table.entryAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalOpenVisitsTableAnnotationComposer
    extends Composer<_$LocalDb, $LocalOpenVisitsTable> {
  $$LocalOpenVisitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get passId =>
      $composableBuilder(column: $table.passId, builder: (column) => column);

  GeneratedColumn<DateTime> get entryAt =>
      $composableBuilder(column: $table.entryAt, builder: (column) => column);
}

class $$LocalOpenVisitsTableTableManager
    extends
        RootTableManager<
          _$LocalDb,
          $LocalOpenVisitsTable,
          LocalOpenVisit,
          $$LocalOpenVisitsTableFilterComposer,
          $$LocalOpenVisitsTableOrderingComposer,
          $$LocalOpenVisitsTableAnnotationComposer,
          $$LocalOpenVisitsTableCreateCompanionBuilder,
          $$LocalOpenVisitsTableUpdateCompanionBuilder,
          (
            LocalOpenVisit,
            BaseReferences<_$LocalDb, $LocalOpenVisitsTable, LocalOpenVisit>,
          ),
          LocalOpenVisit,
          PrefetchHooks Function()
        > {
  $$LocalOpenVisitsTableTableManager(_$LocalDb db, $LocalOpenVisitsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalOpenVisitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalOpenVisitsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalOpenVisitsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> passId = const Value.absent(),
                Value<DateTime> entryAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalOpenVisitsCompanion(
                passId: passId,
                entryAt: entryAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String passId,
                required DateTime entryAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalOpenVisitsCompanion.insert(
                passId: passId,
                entryAt: entryAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalOpenVisitsTable, LocalOpenVisit>(table),
                  BaseReferences<
                    _$LocalDb,
                    $LocalOpenVisitsTable,
                    LocalOpenVisit
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalOpenVisitsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDb,
      $LocalOpenVisitsTable,
      LocalOpenVisit,
      $$LocalOpenVisitsTableFilterComposer,
      $$LocalOpenVisitsTableOrderingComposer,
      $$LocalOpenVisitsTableAnnotationComposer,
      $$LocalOpenVisitsTableCreateCompanionBuilder,
      $$LocalOpenVisitsTableUpdateCompanionBuilder,
      (
        LocalOpenVisit,
        BaseReferences<_$LocalDb, $LocalOpenVisitsTable, LocalOpenVisit>,
      ),
      LocalOpenVisit,
      PrefetchHooks Function()
    >;
typedef $$OutboxTableCreateCompanionBuilder =
    OutboxCompanion Function({
      Value<int> id,
      required String kind,
      required String eventId,
      required String payload,
      Value<Uint8List?> photo,
      required DateTime createdAt,
      Value<int> attempts,
      Value<String?> lastError,
      Value<bool> failed,
    });
typedef $$OutboxTableUpdateCompanionBuilder =
    OutboxCompanion Function({
      Value<int> id,
      Value<String> kind,
      Value<String> eventId,
      Value<String> payload,
      Value<Uint8List?> photo,
      Value<DateTime> createdAt,
      Value<int> attempts,
      Value<String?> lastError,
      Value<bool> failed,
    });

class $$OutboxTableFilterComposer extends Composer<_$LocalDb, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get photo => $composableBuilder(
    column: $table.photo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get failed => $composableBuilder(
    column: $table.failed,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxTableOrderingComposer extends Composer<_$LocalDb, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get photo => $composableBuilder(
    column: $table.photo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get failed => $composableBuilder(
    column: $table.failed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$LocalDb, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<Uint8List> get photo =>
      $composableBuilder(column: $table.photo, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<bool> get failed =>
      $composableBuilder(column: $table.failed, builder: (column) => column);
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$LocalDb,
          $OutboxTable,
          OutboxData,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (OutboxData, BaseReferences<_$LocalDb, $OutboxTable, OutboxData>),
          OutboxData,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$LocalDb db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> eventId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<Uint8List?> photo = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<bool> failed = const Value.absent(),
              }) => OutboxCompanion(
                id: id,
                kind: kind,
                eventId: eventId,
                payload: payload,
                photo: photo,
                createdAt: createdAt,
                attempts: attempts,
                lastError: lastError,
                failed: failed,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String kind,
                required String eventId,
                required String payload,
                Value<Uint8List?> photo = const Value.absent(),
                required DateTime createdAt,
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<bool> failed = const Value.absent(),
              }) => OutboxCompanion.insert(
                id: id,
                kind: kind,
                eventId: eventId,
                payload: payload,
                photo: photo,
                createdAt: createdAt,
                attempts: attempts,
                lastError: lastError,
                failed: failed,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OutboxTable, OutboxData>(table),
                  BaseReferences<_$LocalDb, $OutboxTable, OutboxData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDb,
      $OutboxTable,
      OutboxData,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (OutboxData, BaseReferences<_$LocalDb, $OutboxTable, OutboxData>),
      OutboxData,
      PrefetchHooks Function()
    >;

class $LocalDbManager {
  final _$LocalDb _db;
  $LocalDbManager(this._db);
  $$DeviceSettingsTableTableManager get deviceSettings =>
      $$DeviceSettingsTableTableManager(_db, _db.deviceSettings);
  $$CachedPassesTableTableManager get cachedPasses =>
      $$CachedPassesTableTableManager(_db, _db.cachedPasses);
  $$LocalOpenVisitsTableTableManager get localOpenVisits =>
      $$LocalOpenVisitsTableTableManager(_db, _db.localOpenVisits);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
}
