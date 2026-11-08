// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $WaypointsTable extends Waypoints
    with TableInfo<$WaypointsTable, WaypointRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WaypointsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 80,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lonMeta = const VerificationMeta('lon');
  @override
  late final GeneratedColumn<double> lon = GeneratedColumn<double>(
    'lon',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
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
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _affiliationMeta = const VerificationMeta(
    'affiliation',
  );
  @override
  late final GeneratedColumn<String> affiliation = GeneratedColumn<String>(
    'affiliation',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _echelonMeta = const VerificationMeta(
    'echelon',
  );
  @override
  late final GeneratedColumn<String> echelon = GeneratedColumn<String>(
    'echelon',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
    'uid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cotTypeMeta = const VerificationMeta(
    'cotType',
  );
  @override
  late final GeneratedColumn<String> cotType = GeneratedColumn<String>(
    'cot_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _haeMeta = const VerificationMeta('hae');
  @override
  late final GeneratedColumn<double> hae = GeneratedColumn<double>(
    'hae',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _elevationMeta = const VerificationMeta(
    'elevation',
  );
  @override
  late final GeneratedColumn<double> elevation = GeneratedColumn<double>(
    'elevation',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    lat,
    lon,
    createdAt,
    note,
    affiliation,
    echelon,
    role,
    uid,
    cotType,
    hae,
    elevation,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'waypoints';
  @override
  VerificationContext validateIntegrity(
    Insertable<WaypointRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    } else if (isInserting) {
      context.missing(_latMeta);
    }
    if (data.containsKey('lon')) {
      context.handle(
        _lonMeta,
        lon.isAcceptableOrUnknown(data['lon']!, _lonMeta),
      );
    } else if (isInserting) {
      context.missing(_lonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('affiliation')) {
      context.handle(
        _affiliationMeta,
        affiliation.isAcceptableOrUnknown(
          data['affiliation']!,
          _affiliationMeta,
        ),
      );
    }
    if (data.containsKey('echelon')) {
      context.handle(
        _echelonMeta,
        echelon.isAcceptableOrUnknown(data['echelon']!, _echelonMeta),
      );
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    }
    if (data.containsKey('uid')) {
      context.handle(
        _uidMeta,
        uid.isAcceptableOrUnknown(data['uid']!, _uidMeta),
      );
    }
    if (data.containsKey('cot_type')) {
      context.handle(
        _cotTypeMeta,
        cotType.isAcceptableOrUnknown(data['cot_type']!, _cotTypeMeta),
      );
    }
    if (data.containsKey('hae')) {
      context.handle(
        _haeMeta,
        hae.isAcceptableOrUnknown(data['hae']!, _haeMeta),
      );
    }
    if (data.containsKey('elevation')) {
      context.handle(
        _elevationMeta,
        elevation.isAcceptableOrUnknown(data['elevation']!, _elevationMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WaypointRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WaypointRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      )!,
      lon: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lon'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      affiliation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}affiliation'],
      ),
      echelon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}echelon'],
      ),
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      ),
      uid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uid'],
      ),
      cotType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cot_type'],
      ),
      hae: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}hae'],
      ),
      elevation: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}elevation'],
      ),
    );
  }

  @override
  $WaypointsTable createAlias(String alias) {
    return $WaypointsTable(attachedDatabase, alias);
  }
}

class WaypointRow extends DataClass implements Insertable<WaypointRow> {
  final int id;
  final String name;
  final double lat;
  final double lon;
  final DateTime createdAt;
  final String? note;
  final String? affiliation;
  final String? echelon;
  final String? role;
  final String? uid;
  final String? cotType;
  final double? hae;
  final double? elevation;
  const WaypointRow({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.createdAt,
    this.note,
    this.affiliation,
    this.echelon,
    this.role,
    this.uid,
    this.cotType,
    this.hae,
    this.elevation,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['lat'] = Variable<double>(lat);
    map['lon'] = Variable<double>(lon);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || affiliation != null) {
      map['affiliation'] = Variable<String>(affiliation);
    }
    if (!nullToAbsent || echelon != null) {
      map['echelon'] = Variable<String>(echelon);
    }
    if (!nullToAbsent || role != null) {
      map['role'] = Variable<String>(role);
    }
    if (!nullToAbsent || uid != null) {
      map['uid'] = Variable<String>(uid);
    }
    if (!nullToAbsent || cotType != null) {
      map['cot_type'] = Variable<String>(cotType);
    }
    if (!nullToAbsent || hae != null) {
      map['hae'] = Variable<double>(hae);
    }
    if (!nullToAbsent || elevation != null) {
      map['elevation'] = Variable<double>(elevation);
    }
    return map;
  }

  WaypointsCompanion toCompanion(bool nullToAbsent) {
    return WaypointsCompanion(
      id: Value(id),
      name: Value(name),
      lat: Value(lat),
      lon: Value(lon),
      createdAt: Value(createdAt),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      affiliation: affiliation == null && nullToAbsent
          ? const Value.absent()
          : Value(affiliation),
      echelon: echelon == null && nullToAbsent
          ? const Value.absent()
          : Value(echelon),
      role: role == null && nullToAbsent ? const Value.absent() : Value(role),
      uid: uid == null && nullToAbsent ? const Value.absent() : Value(uid),
      cotType: cotType == null && nullToAbsent
          ? const Value.absent()
          : Value(cotType),
      hae: hae == null && nullToAbsent ? const Value.absent() : Value(hae),
      elevation: elevation == null && nullToAbsent
          ? const Value.absent()
          : Value(elevation),
    );
  }

  factory WaypointRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WaypointRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      lat: serializer.fromJson<double>(json['lat']),
      lon: serializer.fromJson<double>(json['lon']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      note: serializer.fromJson<String?>(json['note']),
      affiliation: serializer.fromJson<String?>(json['affiliation']),
      echelon: serializer.fromJson<String?>(json['echelon']),
      role: serializer.fromJson<String?>(json['role']),
      uid: serializer.fromJson<String?>(json['uid']),
      cotType: serializer.fromJson<String?>(json['cotType']),
      hae: serializer.fromJson<double?>(json['hae']),
      elevation: serializer.fromJson<double?>(json['elevation']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'lat': serializer.toJson<double>(lat),
      'lon': serializer.toJson<double>(lon),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'note': serializer.toJson<String?>(note),
      'affiliation': serializer.toJson<String?>(affiliation),
      'echelon': serializer.toJson<String?>(echelon),
      'role': serializer.toJson<String?>(role),
      'uid': serializer.toJson<String?>(uid),
      'cotType': serializer.toJson<String?>(cotType),
      'hae': serializer.toJson<double?>(hae),
      'elevation': serializer.toJson<double?>(elevation),
    };
  }

  WaypointRow copyWith({
    int? id,
    String? name,
    double? lat,
    double? lon,
    DateTime? createdAt,
    Value<String?> note = const Value.absent(),
    Value<String?> affiliation = const Value.absent(),
    Value<String?> echelon = const Value.absent(),
    Value<String?> role = const Value.absent(),
    Value<String?> uid = const Value.absent(),
    Value<String?> cotType = const Value.absent(),
    Value<double?> hae = const Value.absent(),
    Value<double?> elevation = const Value.absent(),
  }) => WaypointRow(
    id: id ?? this.id,
    name: name ?? this.name,
    lat: lat ?? this.lat,
    lon: lon ?? this.lon,
    createdAt: createdAt ?? this.createdAt,
    note: note.present ? note.value : this.note,
    affiliation: affiliation.present ? affiliation.value : this.affiliation,
    echelon: echelon.present ? echelon.value : this.echelon,
    role: role.present ? role.value : this.role,
    uid: uid.present ? uid.value : this.uid,
    cotType: cotType.present ? cotType.value : this.cotType,
    hae: hae.present ? hae.value : this.hae,
    elevation: elevation.present ? elevation.value : this.elevation,
  );
  WaypointRow copyWithCompanion(WaypointsCompanion data) {
    return WaypointRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      lat: data.lat.present ? data.lat.value : this.lat,
      lon: data.lon.present ? data.lon.value : this.lon,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      note: data.note.present ? data.note.value : this.note,
      affiliation: data.affiliation.present
          ? data.affiliation.value
          : this.affiliation,
      echelon: data.echelon.present ? data.echelon.value : this.echelon,
      role: data.role.present ? data.role.value : this.role,
      uid: data.uid.present ? data.uid.value : this.uid,
      cotType: data.cotType.present ? data.cotType.value : this.cotType,
      hae: data.hae.present ? data.hae.value : this.hae,
      elevation: data.elevation.present ? data.elevation.value : this.elevation,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WaypointRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('lat: $lat, ')
          ..write('lon: $lon, ')
          ..write('createdAt: $createdAt, ')
          ..write('note: $note, ')
          ..write('affiliation: $affiliation, ')
          ..write('echelon: $echelon, ')
          ..write('role: $role, ')
          ..write('uid: $uid, ')
          ..write('cotType: $cotType, ')
          ..write('hae: $hae, ')
          ..write('elevation: $elevation')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    lat,
    lon,
    createdAt,
    note,
    affiliation,
    echelon,
    role,
    uid,
    cotType,
    hae,
    elevation,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WaypointRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.lat == this.lat &&
          other.lon == this.lon &&
          other.createdAt == this.createdAt &&
          other.note == this.note &&
          other.affiliation == this.affiliation &&
          other.echelon == this.echelon &&
          other.role == this.role &&
          other.uid == this.uid &&
          other.cotType == this.cotType &&
          other.hae == this.hae &&
          other.elevation == this.elevation);
}

class WaypointsCompanion extends UpdateCompanion<WaypointRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<double> lat;
  final Value<double> lon;
  final Value<DateTime> createdAt;
  final Value<String?> note;
  final Value<String?> affiliation;
  final Value<String?> echelon;
  final Value<String?> role;
  final Value<String?> uid;
  final Value<String?> cotType;
  final Value<double?> hae;
  final Value<double?> elevation;
  const WaypointsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.lat = const Value.absent(),
    this.lon = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.note = const Value.absent(),
    this.affiliation = const Value.absent(),
    this.echelon = const Value.absent(),
    this.role = const Value.absent(),
    this.uid = const Value.absent(),
    this.cotType = const Value.absent(),
    this.hae = const Value.absent(),
    this.elevation = const Value.absent(),
  });
  WaypointsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required double lat,
    required double lon,
    required DateTime createdAt,
    this.note = const Value.absent(),
    this.affiliation = const Value.absent(),
    this.echelon = const Value.absent(),
    this.role = const Value.absent(),
    this.uid = const Value.absent(),
    this.cotType = const Value.absent(),
    this.hae = const Value.absent(),
    this.elevation = const Value.absent(),
  }) : name = Value(name),
       lat = Value(lat),
       lon = Value(lon),
       createdAt = Value(createdAt);
  static Insertable<WaypointRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<double>? lat,
    Expression<double>? lon,
    Expression<DateTime>? createdAt,
    Expression<String>? note,
    Expression<String>? affiliation,
    Expression<String>? echelon,
    Expression<String>? role,
    Expression<String>? uid,
    Expression<String>? cotType,
    Expression<double>? hae,
    Expression<double>? elevation,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (lat != null) 'lat': lat,
      if (lon != null) 'lon': lon,
      if (createdAt != null) 'created_at': createdAt,
      if (note != null) 'note': note,
      if (affiliation != null) 'affiliation': affiliation,
      if (echelon != null) 'echelon': echelon,
      if (role != null) 'role': role,
      if (uid != null) 'uid': uid,
      if (cotType != null) 'cot_type': cotType,
      if (hae != null) 'hae': hae,
      if (elevation != null) 'elevation': elevation,
    });
  }

  WaypointsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<double>? lat,
    Value<double>? lon,
    Value<DateTime>? createdAt,
    Value<String?>? note,
    Value<String?>? affiliation,
    Value<String?>? echelon,
    Value<String?>? role,
    Value<String?>? uid,
    Value<String?>? cotType,
    Value<double?>? hae,
    Value<double?>? elevation,
  }) {
    return WaypointsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      createdAt: createdAt ?? this.createdAt,
      note: note ?? this.note,
      affiliation: affiliation ?? this.affiliation,
      echelon: echelon ?? this.echelon,
      role: role ?? this.role,
      uid: uid ?? this.uid,
      cotType: cotType ?? this.cotType,
      hae: hae ?? this.hae,
      elevation: elevation ?? this.elevation,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lon.present) {
      map['lon'] = Variable<double>(lon.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (affiliation.present) {
      map['affiliation'] = Variable<String>(affiliation.value);
    }
    if (echelon.present) {
      map['echelon'] = Variable<String>(echelon.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
    }
    if (cotType.present) {
      map['cot_type'] = Variable<String>(cotType.value);
    }
    if (hae.present) {
      map['hae'] = Variable<double>(hae.value);
    }
    if (elevation.present) {
      map['elevation'] = Variable<double>(elevation.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WaypointsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('lat: $lat, ')
          ..write('lon: $lon, ')
          ..write('createdAt: $createdAt, ')
          ..write('note: $note, ')
          ..write('affiliation: $affiliation, ')
          ..write('echelon: $echelon, ')
          ..write('role: $role, ')
          ..write('uid: $uid, ')
          ..write('cotType: $cotType, ')
          ..write('hae: $hae, ')
          ..write('elevation: $elevation')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
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
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
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
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
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
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
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

  Setting copyWith({String? key, String? value}) =>
      Setting(key: key ?? this.key, value: value ?? this.value);
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
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
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
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

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
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
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TracksTable extends Tracks with TableInfo<$TracksTable, TrackRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TracksTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 80,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
    'uid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, startedAt, endedAt, uid];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrackRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('uid')) {
      context.handle(
        _uidMeta,
        uid.isAcceptableOrUnknown(data['uid']!, _uidMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TrackRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrackRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      uid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uid'],
      ),
    );
  }

  @override
  $TracksTable createAlias(String alias) {
    return $TracksTable(attachedDatabase, alias);
  }
}

class TrackRow extends DataClass implements Insertable<TrackRow> {
  final int id;
  final String name;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? uid;
  const TrackRow({
    required this.id,
    required this.name,
    required this.startedAt,
    this.endedAt,
    this.uid,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    if (!nullToAbsent || uid != null) {
      map['uid'] = Variable<String>(uid);
    }
    return map;
  }

  TracksCompanion toCompanion(bool nullToAbsent) {
    return TracksCompanion(
      id: Value(id),
      name: Value(name),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      uid: uid == null && nullToAbsent ? const Value.absent() : Value(uid),
    );
  }

  factory TrackRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrackRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      uid: serializer.fromJson<String?>(json['uid']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'uid': serializer.toJson<String?>(uid),
    };
  }

  TrackRow copyWith({
    int? id,
    String? name,
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
    Value<String?> uid = const Value.absent(),
  }) => TrackRow(
    id: id ?? this.id,
    name: name ?? this.name,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    uid: uid.present ? uid.value : this.uid,
  );
  TrackRow copyWithCompanion(TracksCompanion data) {
    return TrackRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      uid: data.uid.present ? data.uid.value : this.uid,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrackRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('uid: $uid')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, startedAt, endedAt, uid);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.uid == this.uid);
}

class TracksCompanion extends UpdateCompanion<TrackRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<String?> uid;
  const TracksCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.uid = const Value.absent(),
  });
  TracksCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    this.uid = const Value.absent(),
  }) : name = Value(name),
       startedAt = Value(startedAt);
  static Insertable<TrackRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<String>? uid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (uid != null) 'uid': uid,
    });
  }

  TracksCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<String?>? uid,
  }) {
    return TracksCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      uid: uid ?? this.uid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TracksCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('uid: $uid')
          ..write(')'))
        .toString();
  }
}

class $TrackPointsTable extends TrackPoints
    with TableInfo<$TrackPointsTable, TrackPointRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrackPointsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<int> trackId = GeneratedColumn<int>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lonMeta = const VerificationMeta('lon');
  @override
  late final GeneratedColumn<double> lon = GeneratedColumn<double>(
    'lon',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _altitudeMeta = const VerificationMeta(
    'altitude',
  );
  @override
  late final GeneratedColumn<double> altitude = GeneratedColumn<double>(
    'altitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _speedMeta = const VerificationMeta('speed');
  @override
  late final GeneratedColumn<double> speed = GeneratedColumn<double>(
    'speed',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    trackId,
    lat,
    lon,
    timestamp,
    altitude,
    speed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'track_points';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrackPointRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    } else if (isInserting) {
      context.missing(_latMeta);
    }
    if (data.containsKey('lon')) {
      context.handle(
        _lonMeta,
        lon.isAcceptableOrUnknown(data['lon']!, _lonMeta),
      );
    } else if (isInserting) {
      context.missing(_lonMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('altitude')) {
      context.handle(
        _altitudeMeta,
        altitude.isAcceptableOrUnknown(data['altitude']!, _altitudeMeta),
      );
    }
    if (data.containsKey('speed')) {
      context.handle(
        _speedMeta,
        speed.isAcceptableOrUnknown(data['speed']!, _speedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TrackPointRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrackPointRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_id'],
      )!,
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      )!,
      lon: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lon'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      altitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}altitude'],
      ),
      speed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}speed'],
      ),
    );
  }

  @override
  $TrackPointsTable createAlias(String alias) {
    return $TrackPointsTable(attachedDatabase, alias);
  }
}

class TrackPointRow extends DataClass implements Insertable<TrackPointRow> {
  final int id;
  final int trackId;
  final double lat;
  final double lon;
  final DateTime timestamp;
  final double? altitude;
  final double? speed;
  const TrackPointRow({
    required this.id,
    required this.trackId,
    required this.lat,
    required this.lon,
    required this.timestamp,
    this.altitude,
    this.speed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['track_id'] = Variable<int>(trackId);
    map['lat'] = Variable<double>(lat);
    map['lon'] = Variable<double>(lon);
    map['timestamp'] = Variable<DateTime>(timestamp);
    if (!nullToAbsent || altitude != null) {
      map['altitude'] = Variable<double>(altitude);
    }
    if (!nullToAbsent || speed != null) {
      map['speed'] = Variable<double>(speed);
    }
    return map;
  }

  TrackPointsCompanion toCompanion(bool nullToAbsent) {
    return TrackPointsCompanion(
      id: Value(id),
      trackId: Value(trackId),
      lat: Value(lat),
      lon: Value(lon),
      timestamp: Value(timestamp),
      altitude: altitude == null && nullToAbsent
          ? const Value.absent()
          : Value(altitude),
      speed: speed == null && nullToAbsent
          ? const Value.absent()
          : Value(speed),
    );
  }

  factory TrackPointRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrackPointRow(
      id: serializer.fromJson<int>(json['id']),
      trackId: serializer.fromJson<int>(json['trackId']),
      lat: serializer.fromJson<double>(json['lat']),
      lon: serializer.fromJson<double>(json['lon']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      altitude: serializer.fromJson<double?>(json['altitude']),
      speed: serializer.fromJson<double?>(json['speed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trackId': serializer.toJson<int>(trackId),
      'lat': serializer.toJson<double>(lat),
      'lon': serializer.toJson<double>(lon),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'altitude': serializer.toJson<double?>(altitude),
      'speed': serializer.toJson<double?>(speed),
    };
  }

  TrackPointRow copyWith({
    int? id,
    int? trackId,
    double? lat,
    double? lon,
    DateTime? timestamp,
    Value<double?> altitude = const Value.absent(),
    Value<double?> speed = const Value.absent(),
  }) => TrackPointRow(
    id: id ?? this.id,
    trackId: trackId ?? this.trackId,
    lat: lat ?? this.lat,
    lon: lon ?? this.lon,
    timestamp: timestamp ?? this.timestamp,
    altitude: altitude.present ? altitude.value : this.altitude,
    speed: speed.present ? speed.value : this.speed,
  );
  TrackPointRow copyWithCompanion(TrackPointsCompanion data) {
    return TrackPointRow(
      id: data.id.present ? data.id.value : this.id,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      lat: data.lat.present ? data.lat.value : this.lat,
      lon: data.lon.present ? data.lon.value : this.lon,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      altitude: data.altitude.present ? data.altitude.value : this.altitude,
      speed: data.speed.present ? data.speed.value : this.speed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrackPointRow(')
          ..write('id: $id, ')
          ..write('trackId: $trackId, ')
          ..write('lat: $lat, ')
          ..write('lon: $lon, ')
          ..write('timestamp: $timestamp, ')
          ..write('altitude: $altitude, ')
          ..write('speed: $speed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, trackId, lat, lon, timestamp, altitude, speed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackPointRow &&
          other.id == this.id &&
          other.trackId == this.trackId &&
          other.lat == this.lat &&
          other.lon == this.lon &&
          other.timestamp == this.timestamp &&
          other.altitude == this.altitude &&
          other.speed == this.speed);
}

class TrackPointsCompanion extends UpdateCompanion<TrackPointRow> {
  final Value<int> id;
  final Value<int> trackId;
  final Value<double> lat;
  final Value<double> lon;
  final Value<DateTime> timestamp;
  final Value<double?> altitude;
  final Value<double?> speed;
  const TrackPointsCompanion({
    this.id = const Value.absent(),
    this.trackId = const Value.absent(),
    this.lat = const Value.absent(),
    this.lon = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.altitude = const Value.absent(),
    this.speed = const Value.absent(),
  });
  TrackPointsCompanion.insert({
    this.id = const Value.absent(),
    required int trackId,
    required double lat,
    required double lon,
    required DateTime timestamp,
    this.altitude = const Value.absent(),
    this.speed = const Value.absent(),
  }) : trackId = Value(trackId),
       lat = Value(lat),
       lon = Value(lon),
       timestamp = Value(timestamp);
  static Insertable<TrackPointRow> custom({
    Expression<int>? id,
    Expression<int>? trackId,
    Expression<double>? lat,
    Expression<double>? lon,
    Expression<DateTime>? timestamp,
    Expression<double>? altitude,
    Expression<double>? speed,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trackId != null) 'track_id': trackId,
      if (lat != null) 'lat': lat,
      if (lon != null) 'lon': lon,
      if (timestamp != null) 'timestamp': timestamp,
      if (altitude != null) 'altitude': altitude,
      if (speed != null) 'speed': speed,
    });
  }

  TrackPointsCompanion copyWith({
    Value<int>? id,
    Value<int>? trackId,
    Value<double>? lat,
    Value<double>? lon,
    Value<DateTime>? timestamp,
    Value<double?>? altitude,
    Value<double?>? speed,
  }) {
    return TrackPointsCompanion(
      id: id ?? this.id,
      trackId: trackId ?? this.trackId,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      timestamp: timestamp ?? this.timestamp,
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<int>(trackId.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lon.present) {
      map['lon'] = Variable<double>(lon.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (altitude.present) {
      map['altitude'] = Variable<double>(altitude.value);
    }
    if (speed.present) {
      map['speed'] = Variable<double>(speed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrackPointsCompanion(')
          ..write('id: $id, ')
          ..write('trackId: $trackId, ')
          ..write('lat: $lat, ')
          ..write('lon: $lon, ')
          ..write('timestamp: $timestamp, ')
          ..write('altitude: $altitude, ')
          ..write('speed: $speed')
          ..write(')'))
        .toString();
  }
}

class $MapGraphicsTable extends MapGraphics
    with TableInfo<$MapGraphicsTable, MapGraphicRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MapGraphicsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 80,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pointsJsonMeta = const VerificationMeta(
    'pointsJson',
  );
  @override
  late final GeneratedColumn<String> pointsJson = GeneratedColumn<String>(
    'points_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
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
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
    'uid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    type,
    pointsJson,
    color,
    createdAt,
    uid,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'map_graphics';
  @override
  VerificationContext validateIntegrity(
    Insertable<MapGraphicRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('points_json')) {
      context.handle(
        _pointsJsonMeta,
        pointsJson.isAcceptableOrUnknown(data['points_json']!, _pointsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_pointsJsonMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('uid')) {
      context.handle(
        _uidMeta,
        uid.isAcceptableOrUnknown(data['uid']!, _uidMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MapGraphicRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MapGraphicRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      pointsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}points_json'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      uid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uid'],
      ),
    );
  }

  @override
  $MapGraphicsTable createAlias(String alias) {
    return $MapGraphicsTable(attachedDatabase, alias);
  }
}

class MapGraphicRow extends DataClass implements Insertable<MapGraphicRow> {
  final int id;
  final String name;
  final String type;
  final String pointsJson;
  final int color;
  final DateTime createdAt;
  final String? uid;
  const MapGraphicRow({
    required this.id,
    required this.name,
    required this.type,
    required this.pointsJson,
    required this.color,
    required this.createdAt,
    this.uid,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    map['points_json'] = Variable<String>(pointsJson);
    map['color'] = Variable<int>(color);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || uid != null) {
      map['uid'] = Variable<String>(uid);
    }
    return map;
  }

  MapGraphicsCompanion toCompanion(bool nullToAbsent) {
    return MapGraphicsCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      pointsJson: Value(pointsJson),
      color: Value(color),
      createdAt: Value(createdAt),
      uid: uid == null && nullToAbsent ? const Value.absent() : Value(uid),
    );
  }

  factory MapGraphicRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MapGraphicRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      pointsJson: serializer.fromJson<String>(json['pointsJson']),
      color: serializer.fromJson<int>(json['color']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      uid: serializer.fromJson<String?>(json['uid']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'pointsJson': serializer.toJson<String>(pointsJson),
      'color': serializer.toJson<int>(color),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'uid': serializer.toJson<String?>(uid),
    };
  }

  MapGraphicRow copyWith({
    int? id,
    String? name,
    String? type,
    String? pointsJson,
    int? color,
    DateTime? createdAt,
    Value<String?> uid = const Value.absent(),
  }) => MapGraphicRow(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    pointsJson: pointsJson ?? this.pointsJson,
    color: color ?? this.color,
    createdAt: createdAt ?? this.createdAt,
    uid: uid.present ? uid.value : this.uid,
  );
  MapGraphicRow copyWithCompanion(MapGraphicsCompanion data) {
    return MapGraphicRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      pointsJson: data.pointsJson.present
          ? data.pointsJson.value
          : this.pointsJson,
      color: data.color.present ? data.color.value : this.color,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      uid: data.uid.present ? data.uid.value : this.uid,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MapGraphicRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('pointsJson: $pointsJson, ')
          ..write('color: $color, ')
          ..write('createdAt: $createdAt, ')
          ..write('uid: $uid')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, type, pointsJson, color, createdAt, uid);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MapGraphicRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.pointsJson == this.pointsJson &&
          other.color == this.color &&
          other.createdAt == this.createdAt &&
          other.uid == this.uid);
}

class MapGraphicsCompanion extends UpdateCompanion<MapGraphicRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> type;
  final Value<String> pointsJson;
  final Value<int> color;
  final Value<DateTime> createdAt;
  final Value<String?> uid;
  const MapGraphicsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.pointsJson = const Value.absent(),
    this.color = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.uid = const Value.absent(),
  });
  MapGraphicsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String type,
    required String pointsJson,
    required int color,
    required DateTime createdAt,
    this.uid = const Value.absent(),
  }) : name = Value(name),
       type = Value(type),
       pointsJson = Value(pointsJson),
       color = Value(color),
       createdAt = Value(createdAt);
  static Insertable<MapGraphicRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? pointsJson,
    Expression<int>? color,
    Expression<DateTime>? createdAt,
    Expression<String>? uid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (pointsJson != null) 'points_json': pointsJson,
      if (color != null) 'color': color,
      if (createdAt != null) 'created_at': createdAt,
      if (uid != null) 'uid': uid,
    });
  }

  MapGraphicsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? type,
    Value<String>? pointsJson,
    Value<int>? color,
    Value<DateTime>? createdAt,
    Value<String?>? uid,
  }) {
    return MapGraphicsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      pointsJson: pointsJson ?? this.pointsJson,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      uid: uid ?? this.uid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (pointsJson.present) {
      map['points_json'] = Variable<String>(pointsJson.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MapGraphicsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('pointsJson: $pointsJson, ')
          ..write('color: $color, ')
          ..write('createdAt: $createdAt, ')
          ..write('uid: $uid')
          ..write(')'))
        .toString();
  }
}

class $ImportedLayersTable extends ImportedLayers
    with TableInfo<$ImportedLayersTable, ImportedLayerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImportedLayersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 80,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceTypeMeta = const VerificationMeta(
    'sourceType',
  );
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
    'source_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stylePathMeta = const VerificationMeta(
    'stylePath',
  );
  @override
  late final GeneratedColumn<String> stylePath = GeneratedColumn<String>(
    'style_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _minZoomMeta = const VerificationMeta(
    'minZoom',
  );
  @override
  late final GeneratedColumn<int> minZoom = GeneratedColumn<int>(
    'min_zoom',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _maxZoomMeta = const VerificationMeta(
    'maxZoom',
  );
  @override
  late final GeneratedColumn<int> maxZoom = GeneratedColumn<int>(
    'max_zoom',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _centerLatMeta = const VerificationMeta(
    'centerLat',
  );
  @override
  late final GeneratedColumn<double> centerLat = GeneratedColumn<double>(
    'center_lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _centerLonMeta = const VerificationMeta(
    'centerLon',
  );
  @override
  late final GeneratedColumn<double> centerLon = GeneratedColumn<double>(
    'center_lon',
    aliasedName,
    true,
    type: DriftSqlType.double,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    label,
    fileName,
    sourceType,
    stylePath,
    minZoom,
    maxZoom,
    centerLat,
    centerLon,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'imported_layers';
  @override
  VerificationContext validateIntegrity(
    Insertable<ImportedLayerRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('source_type')) {
      context.handle(
        _sourceTypeMeta,
        sourceType.isAcceptableOrUnknown(data['source_type']!, _sourceTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceTypeMeta);
    }
    if (data.containsKey('style_path')) {
      context.handle(
        _stylePathMeta,
        stylePath.isAcceptableOrUnknown(data['style_path']!, _stylePathMeta),
      );
    }
    if (data.containsKey('min_zoom')) {
      context.handle(
        _minZoomMeta,
        minZoom.isAcceptableOrUnknown(data['min_zoom']!, _minZoomMeta),
      );
    }
    if (data.containsKey('max_zoom')) {
      context.handle(
        _maxZoomMeta,
        maxZoom.isAcceptableOrUnknown(data['max_zoom']!, _maxZoomMeta),
      );
    }
    if (data.containsKey('center_lat')) {
      context.handle(
        _centerLatMeta,
        centerLat.isAcceptableOrUnknown(data['center_lat']!, _centerLatMeta),
      );
    }
    if (data.containsKey('center_lon')) {
      context.handle(
        _centerLonMeta,
        centerLon.isAcceptableOrUnknown(data['center_lon']!, _centerLonMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ImportedLayerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImportedLayerRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      sourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_type'],
      )!,
      stylePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}style_path'],
      ),
      minZoom: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}min_zoom'],
      ),
      maxZoom: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_zoom'],
      ),
      centerLat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}center_lat'],
      ),
      centerLon: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}center_lon'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ImportedLayersTable createAlias(String alias) {
    return $ImportedLayersTable(attachedDatabase, alias);
  }
}

class ImportedLayerRow extends DataClass
    implements Insertable<ImportedLayerRow> {
  final String id;
  final String label;
  final String fileName;
  final String sourceType;
  final String? stylePath;
  final int? minZoom;
  final int? maxZoom;
  final double? centerLat;
  final double? centerLon;
  final DateTime createdAt;
  const ImportedLayerRow({
    required this.id,
    required this.label,
    required this.fileName,
    required this.sourceType,
    this.stylePath,
    this.minZoom,
    this.maxZoom,
    this.centerLat,
    this.centerLon,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['label'] = Variable<String>(label);
    map['file_name'] = Variable<String>(fileName);
    map['source_type'] = Variable<String>(sourceType);
    if (!nullToAbsent || stylePath != null) {
      map['style_path'] = Variable<String>(stylePath);
    }
    if (!nullToAbsent || minZoom != null) {
      map['min_zoom'] = Variable<int>(minZoom);
    }
    if (!nullToAbsent || maxZoom != null) {
      map['max_zoom'] = Variable<int>(maxZoom);
    }
    if (!nullToAbsent || centerLat != null) {
      map['center_lat'] = Variable<double>(centerLat);
    }
    if (!nullToAbsent || centerLon != null) {
      map['center_lon'] = Variable<double>(centerLon);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ImportedLayersCompanion toCompanion(bool nullToAbsent) {
    return ImportedLayersCompanion(
      id: Value(id),
      label: Value(label),
      fileName: Value(fileName),
      sourceType: Value(sourceType),
      stylePath: stylePath == null && nullToAbsent
          ? const Value.absent()
          : Value(stylePath),
      minZoom: minZoom == null && nullToAbsent
          ? const Value.absent()
          : Value(minZoom),
      maxZoom: maxZoom == null && nullToAbsent
          ? const Value.absent()
          : Value(maxZoom),
      centerLat: centerLat == null && nullToAbsent
          ? const Value.absent()
          : Value(centerLat),
      centerLon: centerLon == null && nullToAbsent
          ? const Value.absent()
          : Value(centerLon),
      createdAt: Value(createdAt),
    );
  }

  factory ImportedLayerRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImportedLayerRow(
      id: serializer.fromJson<String>(json['id']),
      label: serializer.fromJson<String>(json['label']),
      fileName: serializer.fromJson<String>(json['fileName']),
      sourceType: serializer.fromJson<String>(json['sourceType']),
      stylePath: serializer.fromJson<String?>(json['stylePath']),
      minZoom: serializer.fromJson<int?>(json['minZoom']),
      maxZoom: serializer.fromJson<int?>(json['maxZoom']),
      centerLat: serializer.fromJson<double?>(json['centerLat']),
      centerLon: serializer.fromJson<double?>(json['centerLon']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'label': serializer.toJson<String>(label),
      'fileName': serializer.toJson<String>(fileName),
      'sourceType': serializer.toJson<String>(sourceType),
      'stylePath': serializer.toJson<String?>(stylePath),
      'minZoom': serializer.toJson<int?>(minZoom),
      'maxZoom': serializer.toJson<int?>(maxZoom),
      'centerLat': serializer.toJson<double?>(centerLat),
      'centerLon': serializer.toJson<double?>(centerLon),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ImportedLayerRow copyWith({
    String? id,
    String? label,
    String? fileName,
    String? sourceType,
    Value<String?> stylePath = const Value.absent(),
    Value<int?> minZoom = const Value.absent(),
    Value<int?> maxZoom = const Value.absent(),
    Value<double?> centerLat = const Value.absent(),
    Value<double?> centerLon = const Value.absent(),
    DateTime? createdAt,
  }) => ImportedLayerRow(
    id: id ?? this.id,
    label: label ?? this.label,
    fileName: fileName ?? this.fileName,
    sourceType: sourceType ?? this.sourceType,
    stylePath: stylePath.present ? stylePath.value : this.stylePath,
    minZoom: minZoom.present ? minZoom.value : this.minZoom,
    maxZoom: maxZoom.present ? maxZoom.value : this.maxZoom,
    centerLat: centerLat.present ? centerLat.value : this.centerLat,
    centerLon: centerLon.present ? centerLon.value : this.centerLon,
    createdAt: createdAt ?? this.createdAt,
  );
  ImportedLayerRow copyWithCompanion(ImportedLayersCompanion data) {
    return ImportedLayerRow(
      id: data.id.present ? data.id.value : this.id,
      label: data.label.present ? data.label.value : this.label,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      sourceType: data.sourceType.present
          ? data.sourceType.value
          : this.sourceType,
      stylePath: data.stylePath.present ? data.stylePath.value : this.stylePath,
      minZoom: data.minZoom.present ? data.minZoom.value : this.minZoom,
      maxZoom: data.maxZoom.present ? data.maxZoom.value : this.maxZoom,
      centerLat: data.centerLat.present ? data.centerLat.value : this.centerLat,
      centerLon: data.centerLon.present ? data.centerLon.value : this.centerLon,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImportedLayerRow(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('fileName: $fileName, ')
          ..write('sourceType: $sourceType, ')
          ..write('stylePath: $stylePath, ')
          ..write('minZoom: $minZoom, ')
          ..write('maxZoom: $maxZoom, ')
          ..write('centerLat: $centerLat, ')
          ..write('centerLon: $centerLon, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    label,
    fileName,
    sourceType,
    stylePath,
    minZoom,
    maxZoom,
    centerLat,
    centerLon,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImportedLayerRow &&
          other.id == this.id &&
          other.label == this.label &&
          other.fileName == this.fileName &&
          other.sourceType == this.sourceType &&
          other.stylePath == this.stylePath &&
          other.minZoom == this.minZoom &&
          other.maxZoom == this.maxZoom &&
          other.centerLat == this.centerLat &&
          other.centerLon == this.centerLon &&
          other.createdAt == this.createdAt);
}

class ImportedLayersCompanion extends UpdateCompanion<ImportedLayerRow> {
  final Value<String> id;
  final Value<String> label;
  final Value<String> fileName;
  final Value<String> sourceType;
  final Value<String?> stylePath;
  final Value<int?> minZoom;
  final Value<int?> maxZoom;
  final Value<double?> centerLat;
  final Value<double?> centerLon;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ImportedLayersCompanion({
    this.id = const Value.absent(),
    this.label = const Value.absent(),
    this.fileName = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.stylePath = const Value.absent(),
    this.minZoom = const Value.absent(),
    this.maxZoom = const Value.absent(),
    this.centerLat = const Value.absent(),
    this.centerLon = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ImportedLayersCompanion.insert({
    required String id,
    required String label,
    required String fileName,
    required String sourceType,
    this.stylePath = const Value.absent(),
    this.minZoom = const Value.absent(),
    this.maxZoom = const Value.absent(),
    this.centerLat = const Value.absent(),
    this.centerLon = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       label = Value(label),
       fileName = Value(fileName),
       sourceType = Value(sourceType),
       createdAt = Value(createdAt);
  static Insertable<ImportedLayerRow> custom({
    Expression<String>? id,
    Expression<String>? label,
    Expression<String>? fileName,
    Expression<String>? sourceType,
    Expression<String>? stylePath,
    Expression<int>? minZoom,
    Expression<int>? maxZoom,
    Expression<double>? centerLat,
    Expression<double>? centerLon,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (label != null) 'label': label,
      if (fileName != null) 'file_name': fileName,
      if (sourceType != null) 'source_type': sourceType,
      if (stylePath != null) 'style_path': stylePath,
      if (minZoom != null) 'min_zoom': minZoom,
      if (maxZoom != null) 'max_zoom': maxZoom,
      if (centerLat != null) 'center_lat': centerLat,
      if (centerLon != null) 'center_lon': centerLon,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ImportedLayersCompanion copyWith({
    Value<String>? id,
    Value<String>? label,
    Value<String>? fileName,
    Value<String>? sourceType,
    Value<String?>? stylePath,
    Value<int?>? minZoom,
    Value<int?>? maxZoom,
    Value<double?>? centerLat,
    Value<double?>? centerLon,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ImportedLayersCompanion(
      id: id ?? this.id,
      label: label ?? this.label,
      fileName: fileName ?? this.fileName,
      sourceType: sourceType ?? this.sourceType,
      stylePath: stylePath ?? this.stylePath,
      minZoom: minZoom ?? this.minZoom,
      maxZoom: maxZoom ?? this.maxZoom,
      centerLat: centerLat ?? this.centerLat,
      centerLon: centerLon ?? this.centerLon,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (stylePath.present) {
      map['style_path'] = Variable<String>(stylePath.value);
    }
    if (minZoom.present) {
      map['min_zoom'] = Variable<int>(minZoom.value);
    }
    if (maxZoom.present) {
      map['max_zoom'] = Variable<int>(maxZoom.value);
    }
    if (centerLat.present) {
      map['center_lat'] = Variable<double>(centerLat.value);
    }
    if (centerLon.present) {
      map['center_lon'] = Variable<double>(centerLon.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImportedLayersCompanion(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('fileName: $fileName, ')
          ..write('sourceType: $sourceType, ')
          ..write('stylePath: $stylePath, ')
          ..write('minZoom: $minZoom, ')
          ..write('maxZoom: $maxZoom, ')
          ..write('centerLat: $centerLat, ')
          ..write('centerLon: $centerLon, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RoutePlansTable extends RoutePlans
    with TableInfo<$RoutePlansTable, RoutePlanRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoutePlansTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 80,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pointsJsonMeta = const VerificationMeta(
    'pointsJson',
  );
  @override
  late final GeneratedColumn<String> pointsJson = GeneratedColumn<String>(
    'points_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
    'uid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, pointsJson, createdAt, uid];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'route_plans';
  @override
  VerificationContext validateIntegrity(
    Insertable<RoutePlanRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('points_json')) {
      context.handle(
        _pointsJsonMeta,
        pointsJson.isAcceptableOrUnknown(data['points_json']!, _pointsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_pointsJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('uid')) {
      context.handle(
        _uidMeta,
        uid.isAcceptableOrUnknown(data['uid']!, _uidMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RoutePlanRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RoutePlanRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      pointsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}points_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      uid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uid'],
      ),
    );
  }

  @override
  $RoutePlansTable createAlias(String alias) {
    return $RoutePlansTable(attachedDatabase, alias);
  }
}

class RoutePlanRow extends DataClass implements Insertable<RoutePlanRow> {
  final int id;
  final String name;
  final String pointsJson;
  final DateTime createdAt;
  final String? uid;
  const RoutePlanRow({
    required this.id,
    required this.name,
    required this.pointsJson,
    required this.createdAt,
    this.uid,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['points_json'] = Variable<String>(pointsJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || uid != null) {
      map['uid'] = Variable<String>(uid);
    }
    return map;
  }

  RoutePlansCompanion toCompanion(bool nullToAbsent) {
    return RoutePlansCompanion(
      id: Value(id),
      name: Value(name),
      pointsJson: Value(pointsJson),
      createdAt: Value(createdAt),
      uid: uid == null && nullToAbsent ? const Value.absent() : Value(uid),
    );
  }

  factory RoutePlanRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RoutePlanRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      pointsJson: serializer.fromJson<String>(json['pointsJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      uid: serializer.fromJson<String?>(json['uid']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'pointsJson': serializer.toJson<String>(pointsJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'uid': serializer.toJson<String?>(uid),
    };
  }

  RoutePlanRow copyWith({
    int? id,
    String? name,
    String? pointsJson,
    DateTime? createdAt,
    Value<String?> uid = const Value.absent(),
  }) => RoutePlanRow(
    id: id ?? this.id,
    name: name ?? this.name,
    pointsJson: pointsJson ?? this.pointsJson,
    createdAt: createdAt ?? this.createdAt,
    uid: uid.present ? uid.value : this.uid,
  );
  RoutePlanRow copyWithCompanion(RoutePlansCompanion data) {
    return RoutePlanRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      pointsJson: data.pointsJson.present
          ? data.pointsJson.value
          : this.pointsJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      uid: data.uid.present ? data.uid.value : this.uid,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RoutePlanRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('pointsJson: $pointsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('uid: $uid')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, pointsJson, createdAt, uid);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RoutePlanRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.pointsJson == this.pointsJson &&
          other.createdAt == this.createdAt &&
          other.uid == this.uid);
}

class RoutePlansCompanion extends UpdateCompanion<RoutePlanRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> pointsJson;
  final Value<DateTime> createdAt;
  final Value<String?> uid;
  const RoutePlansCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.pointsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.uid = const Value.absent(),
  });
  RoutePlansCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String pointsJson,
    required DateTime createdAt,
    this.uid = const Value.absent(),
  }) : name = Value(name),
       pointsJson = Value(pointsJson),
       createdAt = Value(createdAt);
  static Insertable<RoutePlanRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? pointsJson,
    Expression<DateTime>? createdAt,
    Expression<String>? uid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (pointsJson != null) 'points_json': pointsJson,
      if (createdAt != null) 'created_at': createdAt,
      if (uid != null) 'uid': uid,
    });
  }

  RoutePlansCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? pointsJson,
    Value<DateTime>? createdAt,
    Value<String?>? uid,
  }) {
    return RoutePlansCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      pointsJson: pointsJson ?? this.pointsJson,
      createdAt: createdAt ?? this.createdAt,
      uid: uid ?? this.uid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (pointsJson.present) {
      map['points_json'] = Variable<String>(pointsJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoutePlansCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('pointsJson: $pointsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('uid: $uid')
          ..write(')'))
        .toString();
  }
}

class $AttachmentsTable extends Attachments
    with TableInfo<$AttachmentsTable, AttachmentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttachmentsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _itemUidMeta = const VerificationMeta(
    'itemUid',
  );
  @override
  late final GeneratedColumn<String> itemUid = GeneratedColumn<String>(
    'item_uid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  @override
  List<GeneratedColumn> get $columns => [id, itemUid, path, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attachments';
  @override
  VerificationContext validateIntegrity(
    Insertable<AttachmentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('item_uid')) {
      context.handle(
        _itemUidMeta,
        itemUid.isAcceptableOrUnknown(data['item_uid']!, _itemUidMeta),
      );
    } else if (isInserting) {
      context.missing(_itemUidMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AttachmentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttachmentRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      itemUid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_uid'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AttachmentsTable createAlias(String alias) {
    return $AttachmentsTable(attachedDatabase, alias);
  }
}

class AttachmentRow extends DataClass implements Insertable<AttachmentRow> {
  final int id;
  final String itemUid;
  final String path;
  final DateTime createdAt;
  const AttachmentRow({
    required this.id,
    required this.itemUid,
    required this.path,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['item_uid'] = Variable<String>(itemUid);
    map['path'] = Variable<String>(path);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AttachmentsCompanion toCompanion(bool nullToAbsent) {
    return AttachmentsCompanion(
      id: Value(id),
      itemUid: Value(itemUid),
      path: Value(path),
      createdAt: Value(createdAt),
    );
  }

  factory AttachmentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttachmentRow(
      id: serializer.fromJson<int>(json['id']),
      itemUid: serializer.fromJson<String>(json['itemUid']),
      path: serializer.fromJson<String>(json['path']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'itemUid': serializer.toJson<String>(itemUid),
      'path': serializer.toJson<String>(path),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AttachmentRow copyWith({
    int? id,
    String? itemUid,
    String? path,
    DateTime? createdAt,
  }) => AttachmentRow(
    id: id ?? this.id,
    itemUid: itemUid ?? this.itemUid,
    path: path ?? this.path,
    createdAt: createdAt ?? this.createdAt,
  );
  AttachmentRow copyWithCompanion(AttachmentsCompanion data) {
    return AttachmentRow(
      id: data.id.present ? data.id.value : this.id,
      itemUid: data.itemUid.present ? data.itemUid.value : this.itemUid,
      path: data.path.present ? data.path.value : this.path,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentRow(')
          ..write('id: $id, ')
          ..write('itemUid: $itemUid, ')
          ..write('path: $path, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, itemUid, path, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttachmentRow &&
          other.id == this.id &&
          other.itemUid == this.itemUid &&
          other.path == this.path &&
          other.createdAt == this.createdAt);
}

class AttachmentsCompanion extends UpdateCompanion<AttachmentRow> {
  final Value<int> id;
  final Value<String> itemUid;
  final Value<String> path;
  final Value<DateTime> createdAt;
  const AttachmentsCompanion({
    this.id = const Value.absent(),
    this.itemUid = const Value.absent(),
    this.path = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  AttachmentsCompanion.insert({
    this.id = const Value.absent(),
    required String itemUid,
    required String path,
    required DateTime createdAt,
  }) : itemUid = Value(itemUid),
       path = Value(path),
       createdAt = Value(createdAt);
  static Insertable<AttachmentRow> custom({
    Expression<int>? id,
    Expression<String>? itemUid,
    Expression<String>? path,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemUid != null) 'item_uid': itemUid,
      if (path != null) 'path': path,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  AttachmentsCompanion copyWith({
    Value<int>? id,
    Value<String>? itemUid,
    Value<String>? path,
    Value<DateTime>? createdAt,
  }) {
    return AttachmentsCompanion(
      id: id ?? this.id,
      itemUid: itemUid ?? this.itemUid,
      path: path ?? this.path,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (itemUid.present) {
      map['item_uid'] = Variable<String>(itemUid.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentsCompanion(')
          ..write('id: $id, ')
          ..write('itemUid: $itemUid, ')
          ..write('path: $path, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $WaypointsTable waypoints = $WaypointsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $TracksTable tracks = $TracksTable(this);
  late final $TrackPointsTable trackPoints = $TrackPointsTable(this);
  late final $MapGraphicsTable mapGraphics = $MapGraphicsTable(this);
  late final $ImportedLayersTable importedLayers = $ImportedLayersTable(this);
  late final $RoutePlansTable routePlans = $RoutePlansTable(this);
  late final $AttachmentsTable attachments = $AttachmentsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    waypoints,
    settings,
    tracks,
    trackPoints,
    mapGraphics,
    importedLayers,
    routePlans,
    attachments,
  ];
}

typedef $$WaypointsTableCreateCompanionBuilder =
    WaypointsCompanion Function({
      Value<int> id,
      required String name,
      required double lat,
      required double lon,
      required DateTime createdAt,
      Value<String?> note,
      Value<String?> affiliation,
      Value<String?> echelon,
      Value<String?> role,
      Value<String?> uid,
      Value<String?> cotType,
      Value<double?> hae,
      Value<double?> elevation,
    });
typedef $$WaypointsTableUpdateCompanionBuilder =
    WaypointsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<double> lat,
      Value<double> lon,
      Value<DateTime> createdAt,
      Value<String?> note,
      Value<String?> affiliation,
      Value<String?> echelon,
      Value<String?> role,
      Value<String?> uid,
      Value<String?> cotType,
      Value<double?> hae,
      Value<double?> elevation,
    });

class $$WaypointsTableFilterComposer
    extends Composer<_$AppDatabase, $WaypointsTable> {
  $$WaypointsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lon => $composableBuilder(
    column: $table.lon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get affiliation => $composableBuilder(
    column: $table.affiliation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get echelon => $composableBuilder(
    column: $table.echelon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cotType => $composableBuilder(
    column: $table.cotType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get hae => $composableBuilder(
    column: $table.hae,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get elevation => $composableBuilder(
    column: $table.elevation,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WaypointsTableOrderingComposer
    extends Composer<_$AppDatabase, $WaypointsTable> {
  $$WaypointsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lon => $composableBuilder(
    column: $table.lon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get affiliation => $composableBuilder(
    column: $table.affiliation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get echelon => $composableBuilder(
    column: $table.echelon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cotType => $composableBuilder(
    column: $table.cotType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get hae => $composableBuilder(
    column: $table.hae,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get elevation => $composableBuilder(
    column: $table.elevation,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WaypointsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WaypointsTable> {
  $$WaypointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lon =>
      $composableBuilder(column: $table.lon, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get affiliation => $composableBuilder(
    column: $table.affiliation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get echelon =>
      $composableBuilder(column: $table.echelon, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

  GeneratedColumn<String> get cotType =>
      $composableBuilder(column: $table.cotType, builder: (column) => column);

  GeneratedColumn<double> get hae =>
      $composableBuilder(column: $table.hae, builder: (column) => column);

  GeneratedColumn<double> get elevation =>
      $composableBuilder(column: $table.elevation, builder: (column) => column);
}

class $$WaypointsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WaypointsTable,
          WaypointRow,
          $$WaypointsTableFilterComposer,
          $$WaypointsTableOrderingComposer,
          $$WaypointsTableAnnotationComposer,
          $$WaypointsTableCreateCompanionBuilder,
          $$WaypointsTableUpdateCompanionBuilder,
          (
            WaypointRow,
            BaseReferences<_$AppDatabase, $WaypointsTable, WaypointRow>,
          ),
          WaypointRow,
          PrefetchHooks Function()
        > {
  $$WaypointsTableTableManager(_$AppDatabase db, $WaypointsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WaypointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WaypointsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WaypointsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> lat = const Value.absent(),
                Value<double> lon = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> affiliation = const Value.absent(),
                Value<String?> echelon = const Value.absent(),
                Value<String?> role = const Value.absent(),
                Value<String?> uid = const Value.absent(),
                Value<String?> cotType = const Value.absent(),
                Value<double?> hae = const Value.absent(),
                Value<double?> elevation = const Value.absent(),
              }) => WaypointsCompanion(
                id: id,
                name: name,
                lat: lat,
                lon: lon,
                createdAt: createdAt,
                note: note,
                affiliation: affiliation,
                echelon: echelon,
                role: role,
                uid: uid,
                cotType: cotType,
                hae: hae,
                elevation: elevation,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required double lat,
                required double lon,
                required DateTime createdAt,
                Value<String?> note = const Value.absent(),
                Value<String?> affiliation = const Value.absent(),
                Value<String?> echelon = const Value.absent(),
                Value<String?> role = const Value.absent(),
                Value<String?> uid = const Value.absent(),
                Value<String?> cotType = const Value.absent(),
                Value<double?> hae = const Value.absent(),
                Value<double?> elevation = const Value.absent(),
              }) => WaypointsCompanion.insert(
                id: id,
                name: name,
                lat: lat,
                lon: lon,
                createdAt: createdAt,
                note: note,
                affiliation: affiliation,
                echelon: echelon,
                role: role,
                uid: uid,
                cotType: cotType,
                hae: hae,
                elevation: elevation,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WaypointsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WaypointsTable,
      WaypointRow,
      $$WaypointsTableFilterComposer,
      $$WaypointsTableOrderingComposer,
      $$WaypointsTableAnnotationComposer,
      $$WaypointsTableCreateCompanionBuilder,
      $$WaypointsTableUpdateCompanionBuilder,
      (
        WaypointRow,
        BaseReferences<_$AppDatabase, $WaypointsTable, WaypointRow>,
      ),
      WaypointRow,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
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

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
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

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
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

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;
typedef $$TracksTableCreateCompanionBuilder =
    TracksCompanion Function({
      Value<int> id,
      required String name,
      required DateTime startedAt,
      Value<DateTime?> endedAt,
      Value<String?> uid,
    });
typedef $$TracksTableUpdateCompanionBuilder =
    TracksCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
      Value<String?> uid,
    });

class $$TracksTableFilterComposer
    extends Composer<_$AppDatabase, $TracksTable> {
  $$TracksTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TracksTableOrderingComposer
    extends Composer<_$AppDatabase, $TracksTable> {
  $$TracksTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TracksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TracksTable> {
  $$TracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);
}

class $$TracksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TracksTable,
          TrackRow,
          $$TracksTableFilterComposer,
          $$TracksTableOrderingComposer,
          $$TracksTableAnnotationComposer,
          $$TracksTableCreateCompanionBuilder,
          $$TracksTableUpdateCompanionBuilder,
          (TrackRow, BaseReferences<_$AppDatabase, $TracksTable, TrackRow>),
          TrackRow,
          PrefetchHooks Function()
        > {
  $$TracksTableTableManager(_$AppDatabase db, $TracksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<String?> uid = const Value.absent(),
              }) => TracksCompanion(
                id: id,
                name: name,
                startedAt: startedAt,
                endedAt: endedAt,
                uid: uid,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
                Value<String?> uid = const Value.absent(),
              }) => TracksCompanion.insert(
                id: id,
                name: name,
                startedAt: startedAt,
                endedAt: endedAt,
                uid: uid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TracksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TracksTable,
      TrackRow,
      $$TracksTableFilterComposer,
      $$TracksTableOrderingComposer,
      $$TracksTableAnnotationComposer,
      $$TracksTableCreateCompanionBuilder,
      $$TracksTableUpdateCompanionBuilder,
      (TrackRow, BaseReferences<_$AppDatabase, $TracksTable, TrackRow>),
      TrackRow,
      PrefetchHooks Function()
    >;
typedef $$TrackPointsTableCreateCompanionBuilder =
    TrackPointsCompanion Function({
      Value<int> id,
      required int trackId,
      required double lat,
      required double lon,
      required DateTime timestamp,
      Value<double?> altitude,
      Value<double?> speed,
    });
typedef $$TrackPointsTableUpdateCompanionBuilder =
    TrackPointsCompanion Function({
      Value<int> id,
      Value<int> trackId,
      Value<double> lat,
      Value<double> lon,
      Value<DateTime> timestamp,
      Value<double?> altitude,
      Value<double?> speed,
    });

class $$TrackPointsTableFilterComposer
    extends Composer<_$AppDatabase, $TrackPointsTable> {
  $$TrackPointsTableFilterComposer({
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

  ColumnFilters<int> get trackId => $composableBuilder(
    column: $table.trackId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lon => $composableBuilder(
    column: $table.lon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get altitude => $composableBuilder(
    column: $table.altitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TrackPointsTableOrderingComposer
    extends Composer<_$AppDatabase, $TrackPointsTable> {
  $$TrackPointsTableOrderingComposer({
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

  ColumnOrderings<int> get trackId => $composableBuilder(
    column: $table.trackId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lon => $composableBuilder(
    column: $table.lon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get altitude => $composableBuilder(
    column: $table.altitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TrackPointsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TrackPointsTable> {
  $$TrackPointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get trackId =>
      $composableBuilder(column: $table.trackId, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lon =>
      $composableBuilder(column: $table.lon, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<double> get altitude =>
      $composableBuilder(column: $table.altitude, builder: (column) => column);

  GeneratedColumn<double> get speed =>
      $composableBuilder(column: $table.speed, builder: (column) => column);
}

class $$TrackPointsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TrackPointsTable,
          TrackPointRow,
          $$TrackPointsTableFilterComposer,
          $$TrackPointsTableOrderingComposer,
          $$TrackPointsTableAnnotationComposer,
          $$TrackPointsTableCreateCompanionBuilder,
          $$TrackPointsTableUpdateCompanionBuilder,
          (
            TrackPointRow,
            BaseReferences<_$AppDatabase, $TrackPointsTable, TrackPointRow>,
          ),
          TrackPointRow,
          PrefetchHooks Function()
        > {
  $$TrackPointsTableTableManager(_$AppDatabase db, $TrackPointsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrackPointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrackPointsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrackPointsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> trackId = const Value.absent(),
                Value<double> lat = const Value.absent(),
                Value<double> lon = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<double?> altitude = const Value.absent(),
                Value<double?> speed = const Value.absent(),
              }) => TrackPointsCompanion(
                id: id,
                trackId: trackId,
                lat: lat,
                lon: lon,
                timestamp: timestamp,
                altitude: altitude,
                speed: speed,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int trackId,
                required double lat,
                required double lon,
                required DateTime timestamp,
                Value<double?> altitude = const Value.absent(),
                Value<double?> speed = const Value.absent(),
              }) => TrackPointsCompanion.insert(
                id: id,
                trackId: trackId,
                lat: lat,
                lon: lon,
                timestamp: timestamp,
                altitude: altitude,
                speed: speed,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TrackPointsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TrackPointsTable,
      TrackPointRow,
      $$TrackPointsTableFilterComposer,
      $$TrackPointsTableOrderingComposer,
      $$TrackPointsTableAnnotationComposer,
      $$TrackPointsTableCreateCompanionBuilder,
      $$TrackPointsTableUpdateCompanionBuilder,
      (
        TrackPointRow,
        BaseReferences<_$AppDatabase, $TrackPointsTable, TrackPointRow>,
      ),
      TrackPointRow,
      PrefetchHooks Function()
    >;
typedef $$MapGraphicsTableCreateCompanionBuilder =
    MapGraphicsCompanion Function({
      Value<int> id,
      required String name,
      required String type,
      required String pointsJson,
      required int color,
      required DateTime createdAt,
      Value<String?> uid,
    });
typedef $$MapGraphicsTableUpdateCompanionBuilder =
    MapGraphicsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> type,
      Value<String> pointsJson,
      Value<int> color,
      Value<DateTime> createdAt,
      Value<String?> uid,
    });

class $$MapGraphicsTableFilterComposer
    extends Composer<_$AppDatabase, $MapGraphicsTable> {
  $$MapGraphicsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pointsJson => $composableBuilder(
    column: $table.pointsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MapGraphicsTableOrderingComposer
    extends Composer<_$AppDatabase, $MapGraphicsTable> {
  $$MapGraphicsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pointsJson => $composableBuilder(
    column: $table.pointsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MapGraphicsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MapGraphicsTable> {
  $$MapGraphicsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get pointsJson => $composableBuilder(
    column: $table.pointsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);
}

class $$MapGraphicsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MapGraphicsTable,
          MapGraphicRow,
          $$MapGraphicsTableFilterComposer,
          $$MapGraphicsTableOrderingComposer,
          $$MapGraphicsTableAnnotationComposer,
          $$MapGraphicsTableCreateCompanionBuilder,
          $$MapGraphicsTableUpdateCompanionBuilder,
          (
            MapGraphicRow,
            BaseReferences<_$AppDatabase, $MapGraphicsTable, MapGraphicRow>,
          ),
          MapGraphicRow,
          PrefetchHooks Function()
        > {
  $$MapGraphicsTableTableManager(_$AppDatabase db, $MapGraphicsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MapGraphicsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MapGraphicsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MapGraphicsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> pointsJson = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> uid = const Value.absent(),
              }) => MapGraphicsCompanion(
                id: id,
                name: name,
                type: type,
                pointsJson: pointsJson,
                color: color,
                createdAt: createdAt,
                uid: uid,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String type,
                required String pointsJson,
                required int color,
                required DateTime createdAt,
                Value<String?> uid = const Value.absent(),
              }) => MapGraphicsCompanion.insert(
                id: id,
                name: name,
                type: type,
                pointsJson: pointsJson,
                color: color,
                createdAt: createdAt,
                uid: uid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MapGraphicsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MapGraphicsTable,
      MapGraphicRow,
      $$MapGraphicsTableFilterComposer,
      $$MapGraphicsTableOrderingComposer,
      $$MapGraphicsTableAnnotationComposer,
      $$MapGraphicsTableCreateCompanionBuilder,
      $$MapGraphicsTableUpdateCompanionBuilder,
      (
        MapGraphicRow,
        BaseReferences<_$AppDatabase, $MapGraphicsTable, MapGraphicRow>,
      ),
      MapGraphicRow,
      PrefetchHooks Function()
    >;
typedef $$ImportedLayersTableCreateCompanionBuilder =
    ImportedLayersCompanion Function({
      required String id,
      required String label,
      required String fileName,
      required String sourceType,
      Value<String?> stylePath,
      Value<int?> minZoom,
      Value<int?> maxZoom,
      Value<double?> centerLat,
      Value<double?> centerLon,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ImportedLayersTableUpdateCompanionBuilder =
    ImportedLayersCompanion Function({
      Value<String> id,
      Value<String> label,
      Value<String> fileName,
      Value<String> sourceType,
      Value<String?> stylePath,
      Value<int?> minZoom,
      Value<int?> maxZoom,
      Value<double?> centerLat,
      Value<double?> centerLon,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$ImportedLayersTableFilterComposer
    extends Composer<_$AppDatabase, $ImportedLayersTable> {
  $$ImportedLayersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stylePath => $composableBuilder(
    column: $table.stylePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minZoom => $composableBuilder(
    column: $table.minZoom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxZoom => $composableBuilder(
    column: $table.maxZoom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get centerLat => $composableBuilder(
    column: $table.centerLat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get centerLon => $composableBuilder(
    column: $table.centerLon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ImportedLayersTableOrderingComposer
    extends Composer<_$AppDatabase, $ImportedLayersTable> {
  $$ImportedLayersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stylePath => $composableBuilder(
    column: $table.stylePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minZoom => $composableBuilder(
    column: $table.minZoom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxZoom => $composableBuilder(
    column: $table.maxZoom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get centerLat => $composableBuilder(
    column: $table.centerLat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get centerLon => $composableBuilder(
    column: $table.centerLon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ImportedLayersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ImportedLayersTable> {
  $$ImportedLayersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get stylePath =>
      $composableBuilder(column: $table.stylePath, builder: (column) => column);

  GeneratedColumn<int> get minZoom =>
      $composableBuilder(column: $table.minZoom, builder: (column) => column);

  GeneratedColumn<int> get maxZoom =>
      $composableBuilder(column: $table.maxZoom, builder: (column) => column);

  GeneratedColumn<double> get centerLat =>
      $composableBuilder(column: $table.centerLat, builder: (column) => column);

  GeneratedColumn<double> get centerLon =>
      $composableBuilder(column: $table.centerLon, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ImportedLayersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ImportedLayersTable,
          ImportedLayerRow,
          $$ImportedLayersTableFilterComposer,
          $$ImportedLayersTableOrderingComposer,
          $$ImportedLayersTableAnnotationComposer,
          $$ImportedLayersTableCreateCompanionBuilder,
          $$ImportedLayersTableUpdateCompanionBuilder,
          (
            ImportedLayerRow,
            BaseReferences<
              _$AppDatabase,
              $ImportedLayersTable,
              ImportedLayerRow
            >,
          ),
          ImportedLayerRow,
          PrefetchHooks Function()
        > {
  $$ImportedLayersTableTableManager(
    _$AppDatabase db,
    $ImportedLayersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImportedLayersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImportedLayersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImportedLayersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<String> sourceType = const Value.absent(),
                Value<String?> stylePath = const Value.absent(),
                Value<int?> minZoom = const Value.absent(),
                Value<int?> maxZoom = const Value.absent(),
                Value<double?> centerLat = const Value.absent(),
                Value<double?> centerLon = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ImportedLayersCompanion(
                id: id,
                label: label,
                fileName: fileName,
                sourceType: sourceType,
                stylePath: stylePath,
                minZoom: minZoom,
                maxZoom: maxZoom,
                centerLat: centerLat,
                centerLon: centerLon,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String label,
                required String fileName,
                required String sourceType,
                Value<String?> stylePath = const Value.absent(),
                Value<int?> minZoom = const Value.absent(),
                Value<int?> maxZoom = const Value.absent(),
                Value<double?> centerLat = const Value.absent(),
                Value<double?> centerLon = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ImportedLayersCompanion.insert(
                id: id,
                label: label,
                fileName: fileName,
                sourceType: sourceType,
                stylePath: stylePath,
                minZoom: minZoom,
                maxZoom: maxZoom,
                centerLat: centerLat,
                centerLon: centerLon,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ImportedLayersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ImportedLayersTable,
      ImportedLayerRow,
      $$ImportedLayersTableFilterComposer,
      $$ImportedLayersTableOrderingComposer,
      $$ImportedLayersTableAnnotationComposer,
      $$ImportedLayersTableCreateCompanionBuilder,
      $$ImportedLayersTableUpdateCompanionBuilder,
      (
        ImportedLayerRow,
        BaseReferences<_$AppDatabase, $ImportedLayersTable, ImportedLayerRow>,
      ),
      ImportedLayerRow,
      PrefetchHooks Function()
    >;
typedef $$RoutePlansTableCreateCompanionBuilder =
    RoutePlansCompanion Function({
      Value<int> id,
      required String name,
      required String pointsJson,
      required DateTime createdAt,
      Value<String?> uid,
    });
typedef $$RoutePlansTableUpdateCompanionBuilder =
    RoutePlansCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> pointsJson,
      Value<DateTime> createdAt,
      Value<String?> uid,
    });

class $$RoutePlansTableFilterComposer
    extends Composer<_$AppDatabase, $RoutePlansTable> {
  $$RoutePlansTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pointsJson => $composableBuilder(
    column: $table.pointsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RoutePlansTableOrderingComposer
    extends Composer<_$AppDatabase, $RoutePlansTable> {
  $$RoutePlansTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pointsJson => $composableBuilder(
    column: $table.pointsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RoutePlansTableAnnotationComposer
    extends Composer<_$AppDatabase, $RoutePlansTable> {
  $$RoutePlansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get pointsJson => $composableBuilder(
    column: $table.pointsJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);
}

class $$RoutePlansTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RoutePlansTable,
          RoutePlanRow,
          $$RoutePlansTableFilterComposer,
          $$RoutePlansTableOrderingComposer,
          $$RoutePlansTableAnnotationComposer,
          $$RoutePlansTableCreateCompanionBuilder,
          $$RoutePlansTableUpdateCompanionBuilder,
          (
            RoutePlanRow,
            BaseReferences<_$AppDatabase, $RoutePlansTable, RoutePlanRow>,
          ),
          RoutePlanRow,
          PrefetchHooks Function()
        > {
  $$RoutePlansTableTableManager(_$AppDatabase db, $RoutePlansTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoutePlansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RoutePlansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RoutePlansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> pointsJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> uid = const Value.absent(),
              }) => RoutePlansCompanion(
                id: id,
                name: name,
                pointsJson: pointsJson,
                createdAt: createdAt,
                uid: uid,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String pointsJson,
                required DateTime createdAt,
                Value<String?> uid = const Value.absent(),
              }) => RoutePlansCompanion.insert(
                id: id,
                name: name,
                pointsJson: pointsJson,
                createdAt: createdAt,
                uid: uid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RoutePlansTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RoutePlansTable,
      RoutePlanRow,
      $$RoutePlansTableFilterComposer,
      $$RoutePlansTableOrderingComposer,
      $$RoutePlansTableAnnotationComposer,
      $$RoutePlansTableCreateCompanionBuilder,
      $$RoutePlansTableUpdateCompanionBuilder,
      (
        RoutePlanRow,
        BaseReferences<_$AppDatabase, $RoutePlansTable, RoutePlanRow>,
      ),
      RoutePlanRow,
      PrefetchHooks Function()
    >;
typedef $$AttachmentsTableCreateCompanionBuilder =
    AttachmentsCompanion Function({
      Value<int> id,
      required String itemUid,
      required String path,
      required DateTime createdAt,
    });
typedef $$AttachmentsTableUpdateCompanionBuilder =
    AttachmentsCompanion Function({
      Value<int> id,
      Value<String> itemUid,
      Value<String> path,
      Value<DateTime> createdAt,
    });

class $$AttachmentsTableFilterComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableFilterComposer({
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

  ColumnFilters<String> get itemUid => $composableBuilder(
    column: $table.itemUid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AttachmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableOrderingComposer({
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

  ColumnOrderings<String> get itemUid => $composableBuilder(
    column: $table.itemUid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AttachmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get itemUid =>
      $composableBuilder(column: $table.itemUid, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AttachmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttachmentsTable,
          AttachmentRow,
          $$AttachmentsTableFilterComposer,
          $$AttachmentsTableOrderingComposer,
          $$AttachmentsTableAnnotationComposer,
          $$AttachmentsTableCreateCompanionBuilder,
          $$AttachmentsTableUpdateCompanionBuilder,
          (
            AttachmentRow,
            BaseReferences<_$AppDatabase, $AttachmentsTable, AttachmentRow>,
          ),
          AttachmentRow,
          PrefetchHooks Function()
        > {
  $$AttachmentsTableTableManager(_$AppDatabase db, $AttachmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttachmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttachmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttachmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> itemUid = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => AttachmentsCompanion(
                id: id,
                itemUid: itemUid,
                path: path,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String itemUid,
                required String path,
                required DateTime createdAt,
              }) => AttachmentsCompanion.insert(
                id: id,
                itemUid: itemUid,
                path: path,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AttachmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttachmentsTable,
      AttachmentRow,
      $$AttachmentsTableFilterComposer,
      $$AttachmentsTableOrderingComposer,
      $$AttachmentsTableAnnotationComposer,
      $$AttachmentsTableCreateCompanionBuilder,
      $$AttachmentsTableUpdateCompanionBuilder,
      (
        AttachmentRow,
        BaseReferences<_$AppDatabase, $AttachmentsTable, AttachmentRow>,
      ),
      AttachmentRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$WaypointsTableTableManager get waypoints =>
      $$WaypointsTableTableManager(_db, _db.waypoints);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$TracksTableTableManager get tracks =>
      $$TracksTableTableManager(_db, _db.tracks);
  $$TrackPointsTableTableManager get trackPoints =>
      $$TrackPointsTableTableManager(_db, _db.trackPoints);
  $$MapGraphicsTableTableManager get mapGraphics =>
      $$MapGraphicsTableTableManager(_db, _db.mapGraphics);
  $$ImportedLayersTableTableManager get importedLayers =>
      $$ImportedLayersTableTableManager(_db, _db.importedLayers);
  $$RoutePlansTableTableManager get routePlans =>
      $$RoutePlansTableTableManager(_db, _db.routePlans);
  $$AttachmentsTableTableManager get attachments =>
      $$AttachmentsTableTableManager(_db, _db.attachments);
}
