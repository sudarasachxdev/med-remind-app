// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    check: () => id.equals(appSettingsRowId),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(appSettingsRowId),
  );
  static const VerificationMeta _onboardingCompletedMeta =
      const VerificationMeta('onboardingCompleted');
  @override
  late final GeneratedColumn<bool> onboardingCompleted = GeneratedColumn<bool>(
    'onboarding_completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("onboarding_completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, onboardingCompleted];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('onboarding_completed')) {
      context.handle(
        _onboardingCompletedMeta,
        onboardingCompleted.isAcceptableOrUnknown(
          data['onboarding_completed']!,
          _onboardingCompletedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      onboardingCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}onboarding_completed'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  /// Always [appSettingsRowId]. The check constraint is what makes this table
  /// single-row.
  ///
  /// The self-reference below is drift's documented way to attach a `CHECK` to
  /// a column -- the constraint has to name the column it constrains -- so the
  /// `recursive_getters` warning is a false positive: drift reads the
  /// expression once at build time and emits it into the `CREATE TABLE`. The
  /// getter is never called at runtime, so nothing recurses.
  final int id;

  /// Whether the user has reached Home through the onboarding panels.
  ///
  /// Defaults to `false` so that a row inserted for some other setting does not
  /// silently claim onboarding was seen.
  final bool onboardingCompleted;
  const AppSetting({required this.id, required this.onboardingCompleted});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['onboarding_completed'] = Variable<bool>(onboardingCompleted);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      id: Value(id),
      onboardingCompleted: Value(onboardingCompleted),
    );
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      id: serializer.fromJson<int>(json['id']),
      onboardingCompleted: serializer.fromJson<bool>(
        json['onboardingCompleted'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'onboardingCompleted': serializer.toJson<bool>(onboardingCompleted),
    };
  }

  AppSetting copyWith({int? id, bool? onboardingCompleted}) => AppSetting(
    id: id ?? this.id,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
  );
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      id: data.id.present ? data.id.value : this.id,
      onboardingCompleted: data.onboardingCompleted.present
          ? data.onboardingCompleted.value
          : this.onboardingCompleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('id: $id, ')
          ..write('onboardingCompleted: $onboardingCompleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, onboardingCompleted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.id == this.id &&
          other.onboardingCompleted == this.onboardingCompleted);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<int> id;
  final Value<bool> onboardingCompleted;
  const AppSettingsCompanion({
    this.id = const Value.absent(),
    this.onboardingCompleted = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.onboardingCompleted = const Value.absent(),
  });
  static Insertable<AppSetting> custom({
    Expression<int>? id,
    Expression<bool>? onboardingCompleted,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (onboardingCompleted != null)
        'onboarding_completed': onboardingCompleted,
    });
  }

  AppSettingsCompanion copyWith({
    Value<int>? id,
    Value<bool>? onboardingCompleted,
  }) {
    return AppSettingsCompanion(
      id: id ?? this.id,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (onboardingCompleted.present) {
      map['onboarding_completed'] = Variable<bool>(onboardingCompleted.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('id: $id, ')
          ..write('onboardingCompleted: $onboardingCompleted')
          ..write(')'))
        .toString();
  }
}

class $MedicinesTable extends Medicines
    with TableInfo<$MedicinesTable, MedicineRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MedicinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conditionMeta = const VerificationMeta(
    'condition',
  );
  @override
  late final GeneratedColumn<String> condition = GeneratedColumn<String>(
    'condition',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _glyphIndexMeta = const VerificationMeta(
    'glyphIndex',
  );
  @override
  late final GeneratedColumn<int> glyphIndex = GeneratedColumn<int>(
    'glyph_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formMeta = const VerificationMeta('form');
  @override
  late final GeneratedColumn<String> form = GeneratedColumn<String>(
    'form',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dosageAmountMeta = const VerificationMeta(
    'dosageAmount',
  );
  @override
  late final GeneratedColumn<double> dosageAmount = GeneratedColumn<double>(
    'dosage_amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dosageUnitMeta = const VerificationMeta(
    'dosageUnit',
  );
  @override
  late final GeneratedColumn<String> dosageUnit = GeneratedColumn<String>(
    'dosage_unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _instructionsMeta = const VerificationMeta(
    'instructions',
  );
  @override
  late final GeneratedColumn<String> instructions = GeneratedColumn<String>(
    'instructions',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<String> startDate = GeneratedColumn<String>(
    'start_date',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>(
      '"start_date" GLOB \'[0-9][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9]\'',
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<String> endDate = GeneratedColumn<String>(
    'end_date',
    aliasedName,
    true,
    check: () => const CustomExpression<bool>(
      '"end_date" GLOB \'[0-9][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9]\'',
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    condition,
    glyphIndex,
    form,
    dosageAmount,
    dosageUnit,
    instructions,
    startDate,
    endDate,
    active,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'medicines';
  @override
  VerificationContext validateIntegrity(
    Insertable<MedicineRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('condition')) {
      context.handle(
        _conditionMeta,
        condition.isAcceptableOrUnknown(data['condition']!, _conditionMeta),
      );
    }
    if (data.containsKey('glyph_index')) {
      context.handle(
        _glyphIndexMeta,
        glyphIndex.isAcceptableOrUnknown(data['glyph_index']!, _glyphIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_glyphIndexMeta);
    }
    if (data.containsKey('form')) {
      context.handle(
        _formMeta,
        form.isAcceptableOrUnknown(data['form']!, _formMeta),
      );
    } else if (isInserting) {
      context.missing(_formMeta);
    }
    if (data.containsKey('dosage_amount')) {
      context.handle(
        _dosageAmountMeta,
        dosageAmount.isAcceptableOrUnknown(
          data['dosage_amount']!,
          _dosageAmountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dosageAmountMeta);
    }
    if (data.containsKey('dosage_unit')) {
      context.handle(
        _dosageUnitMeta,
        dosageUnit.isAcceptableOrUnknown(data['dosage_unit']!, _dosageUnitMeta),
      );
    } else if (isInserting) {
      context.missing(_dosageUnitMeta);
    }
    if (data.containsKey('instructions')) {
      context.handle(
        _instructionsMeta,
        instructions.isAcceptableOrUnknown(
          data['instructions']!,
          _instructionsMeta,
        ),
      );
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MedicineRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MedicineRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      condition: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}condition'],
      ),
      glyphIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}glyph_index'],
      )!,
      form: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}form'],
      )!,
      dosageAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}dosage_amount'],
      )!,
      dosageUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dosage_unit'],
      )!,
      instructions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}instructions'],
      ),
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_date'],
      )!,
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_date'],
      ),
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
    );
  }

  @override
  $MedicinesTable createAlias(String alias) {
    return $MedicinesTable(attachedDatabase, alias);
  }
}

class MedicineRow extends DataClass implements Insertable<MedicineRow> {
  /// UUID v4, as text (the spine's Identifiers convention).
  final String id;

  /// What the user calls it (FR-1).
  final String name;

  /// What it is for, in the user's own words. Free text, displayed and never
  /// interpreted — the PRD forbids validating it or looking it up — hence no
  /// length or format constraint here beyond nullability.
  final String? condition;

  /// Which of the design system's four glyphs represents this Medicine.
  ///
  /// AD-22: assigned once at creation as `count(existing medicines) mod 4`,
  /// persisted here, and never recomputed. Deliberately carries no `CHECK`
  /// against the glyph count: the count is a design decision that may grow, and
  /// a schema constraint would turn growing it into a third migration for no
  /// safety a test does not already give.
  final int glyphIndex;

  /// Tablet, capsule, drops (FR-1).
  final String form;

  /// How much is taken per dose by default (FR-1). Real, because half a tablet
  /// and 2.5 ml are both ordinary.
  final double dosageAmount;

  /// The unit [dosageAmount] is counted in (FR-1).
  final String dosageUnit;

  /// Anything else the user wants to remember. Not captured by the Story 1.5
  /// add flow, deliberately; the column exists so editing can gain it without
  /// a migration.
  final String? instructions;

  /// The calendar day the regimen begins, as `YYYY-MM-DD`.
  ///
  /// The self-reference in the `check` is drift's documented way to attach a
  /// `CHECK` to a column -- the constraint has to name the column it
  /// constrains -- so the `recursive_getters` warning is a false positive:
  /// drift reads the expression once at build time and emits it into the
  /// `CREATE TABLE`. The getter is never called at runtime.
  final String startDate;

  /// The calendar day it ends, inclusive, or null for open-ended.
  final String? endDate;

  /// Whether the medicine is currently being taken.
  ///
  /// Separate from deletion: stopping a medicine must not erase the history of
  /// having taken it. Defaults to true — a medicine is added in order to take
  /// it.
  final bool active;
  const MedicineRow({
    required this.id,
    required this.name,
    this.condition,
    required this.glyphIndex,
    required this.form,
    required this.dosageAmount,
    required this.dosageUnit,
    this.instructions,
    required this.startDate,
    this.endDate,
    required this.active,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || condition != null) {
      map['condition'] = Variable<String>(condition);
    }
    map['glyph_index'] = Variable<int>(glyphIndex);
    map['form'] = Variable<String>(form);
    map['dosage_amount'] = Variable<double>(dosageAmount);
    map['dosage_unit'] = Variable<String>(dosageUnit);
    if (!nullToAbsent || instructions != null) {
      map['instructions'] = Variable<String>(instructions);
    }
    map['start_date'] = Variable<String>(startDate);
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<String>(endDate);
    }
    map['active'] = Variable<bool>(active);
    return map;
  }

  MedicinesCompanion toCompanion(bool nullToAbsent) {
    return MedicinesCompanion(
      id: Value(id),
      name: Value(name),
      condition: condition == null && nullToAbsent
          ? const Value.absent()
          : Value(condition),
      glyphIndex: Value(glyphIndex),
      form: Value(form),
      dosageAmount: Value(dosageAmount),
      dosageUnit: Value(dosageUnit),
      instructions: instructions == null && nullToAbsent
          ? const Value.absent()
          : Value(instructions),
      startDate: Value(startDate),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      active: Value(active),
    );
  }

  factory MedicineRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MedicineRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      condition: serializer.fromJson<String?>(json['condition']),
      glyphIndex: serializer.fromJson<int>(json['glyphIndex']),
      form: serializer.fromJson<String>(json['form']),
      dosageAmount: serializer.fromJson<double>(json['dosageAmount']),
      dosageUnit: serializer.fromJson<String>(json['dosageUnit']),
      instructions: serializer.fromJson<String?>(json['instructions']),
      startDate: serializer.fromJson<String>(json['startDate']),
      endDate: serializer.fromJson<String?>(json['endDate']),
      active: serializer.fromJson<bool>(json['active']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'condition': serializer.toJson<String?>(condition),
      'glyphIndex': serializer.toJson<int>(glyphIndex),
      'form': serializer.toJson<String>(form),
      'dosageAmount': serializer.toJson<double>(dosageAmount),
      'dosageUnit': serializer.toJson<String>(dosageUnit),
      'instructions': serializer.toJson<String?>(instructions),
      'startDate': serializer.toJson<String>(startDate),
      'endDate': serializer.toJson<String?>(endDate),
      'active': serializer.toJson<bool>(active),
    };
  }

  MedicineRow copyWith({
    String? id,
    String? name,
    Value<String?> condition = const Value.absent(),
    int? glyphIndex,
    String? form,
    double? dosageAmount,
    String? dosageUnit,
    Value<String?> instructions = const Value.absent(),
    String? startDate,
    Value<String?> endDate = const Value.absent(),
    bool? active,
  }) => MedicineRow(
    id: id ?? this.id,
    name: name ?? this.name,
    condition: condition.present ? condition.value : this.condition,
    glyphIndex: glyphIndex ?? this.glyphIndex,
    form: form ?? this.form,
    dosageAmount: dosageAmount ?? this.dosageAmount,
    dosageUnit: dosageUnit ?? this.dosageUnit,
    instructions: instructions.present ? instructions.value : this.instructions,
    startDate: startDate ?? this.startDate,
    endDate: endDate.present ? endDate.value : this.endDate,
    active: active ?? this.active,
  );
  MedicineRow copyWithCompanion(MedicinesCompanion data) {
    return MedicineRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      condition: data.condition.present ? data.condition.value : this.condition,
      glyphIndex: data.glyphIndex.present
          ? data.glyphIndex.value
          : this.glyphIndex,
      form: data.form.present ? data.form.value : this.form,
      dosageAmount: data.dosageAmount.present
          ? data.dosageAmount.value
          : this.dosageAmount,
      dosageUnit: data.dosageUnit.present
          ? data.dosageUnit.value
          : this.dosageUnit,
      instructions: data.instructions.present
          ? data.instructions.value
          : this.instructions,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      active: data.active.present ? data.active.value : this.active,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MedicineRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('condition: $condition, ')
          ..write('glyphIndex: $glyphIndex, ')
          ..write('form: $form, ')
          ..write('dosageAmount: $dosageAmount, ')
          ..write('dosageUnit: $dosageUnit, ')
          ..write('instructions: $instructions, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('active: $active')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    condition,
    glyphIndex,
    form,
    dosageAmount,
    dosageUnit,
    instructions,
    startDate,
    endDate,
    active,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MedicineRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.condition == this.condition &&
          other.glyphIndex == this.glyphIndex &&
          other.form == this.form &&
          other.dosageAmount == this.dosageAmount &&
          other.dosageUnit == this.dosageUnit &&
          other.instructions == this.instructions &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.active == this.active);
}

class MedicinesCompanion extends UpdateCompanion<MedicineRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> condition;
  final Value<int> glyphIndex;
  final Value<String> form;
  final Value<double> dosageAmount;
  final Value<String> dosageUnit;
  final Value<String?> instructions;
  final Value<String> startDate;
  final Value<String?> endDate;
  final Value<bool> active;
  final Value<int> rowid;
  const MedicinesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.condition = const Value.absent(),
    this.glyphIndex = const Value.absent(),
    this.form = const Value.absent(),
    this.dosageAmount = const Value.absent(),
    this.dosageUnit = const Value.absent(),
    this.instructions = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.active = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MedicinesCompanion.insert({
    required String id,
    required String name,
    this.condition = const Value.absent(),
    required int glyphIndex,
    required String form,
    required double dosageAmount,
    required String dosageUnit,
    this.instructions = const Value.absent(),
    required String startDate,
    this.endDate = const Value.absent(),
    this.active = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       glyphIndex = Value(glyphIndex),
       form = Value(form),
       dosageAmount = Value(dosageAmount),
       dosageUnit = Value(dosageUnit),
       startDate = Value(startDate);
  static Insertable<MedicineRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? condition,
    Expression<int>? glyphIndex,
    Expression<String>? form,
    Expression<double>? dosageAmount,
    Expression<String>? dosageUnit,
    Expression<String>? instructions,
    Expression<String>? startDate,
    Expression<String>? endDate,
    Expression<bool>? active,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (condition != null) 'condition': condition,
      if (glyphIndex != null) 'glyph_index': glyphIndex,
      if (form != null) 'form': form,
      if (dosageAmount != null) 'dosage_amount': dosageAmount,
      if (dosageUnit != null) 'dosage_unit': dosageUnit,
      if (instructions != null) 'instructions': instructions,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (active != null) 'active': active,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MedicinesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? condition,
    Value<int>? glyphIndex,
    Value<String>? form,
    Value<double>? dosageAmount,
    Value<String>? dosageUnit,
    Value<String?>? instructions,
    Value<String>? startDate,
    Value<String?>? endDate,
    Value<bool>? active,
    Value<int>? rowid,
  }) {
    return MedicinesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      condition: condition ?? this.condition,
      glyphIndex: glyphIndex ?? this.glyphIndex,
      form: form ?? this.form,
      dosageAmount: dosageAmount ?? this.dosageAmount,
      dosageUnit: dosageUnit ?? this.dosageUnit,
      instructions: instructions ?? this.instructions,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      active: active ?? this.active,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (condition.present) {
      map['condition'] = Variable<String>(condition.value);
    }
    if (glyphIndex.present) {
      map['glyph_index'] = Variable<int>(glyphIndex.value);
    }
    if (form.present) {
      map['form'] = Variable<String>(form.value);
    }
    if (dosageAmount.present) {
      map['dosage_amount'] = Variable<double>(dosageAmount.value);
    }
    if (dosageUnit.present) {
      map['dosage_unit'] = Variable<String>(dosageUnit.value);
    }
    if (instructions.present) {
      map['instructions'] = Variable<String>(instructions.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<String>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<String>(endDate.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MedicinesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('condition: $condition, ')
          ..write('glyphIndex: $glyphIndex, ')
          ..write('form: $form, ')
          ..write('dosageAmount: $dosageAmount, ')
          ..write('dosageUnit: $dosageUnit, ')
          ..write('instructions: $instructions, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('active: $active, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SchedulesTable extends Schedules
    with TableInfo<$SchedulesTable, ScheduleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SchedulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _medicineIdMeta = const VerificationMeta(
    'medicineId',
  );
  @override
  late final GeneratedColumn<String> medicineId = GeneratedColumn<String>(
    'medicine_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES medicines (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _timeOfDayMeta = const VerificationMeta(
    'timeOfDay',
  );
  @override
  late final GeneratedColumn<String> timeOfDay = GeneratedColumn<String>(
    'time_of_day',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>(
      '"time_of_day" GLOB \'[0-2][0-9]:[0-5][0-9]\'',
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ianaTimezoneMeta = const VerificationMeta(
    'ianaTimezone',
  );
  @override
  late final GeneratedColumn<String> ianaTimezone = GeneratedColumn<String>(
    'iana_timezone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _frequencyMeta = const VerificationMeta(
    'frequency',
  );
  @override
  late final GeneratedColumn<String> frequency = GeneratedColumn<String>(
    'frequency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _daysOfWeekMeta = const VerificationMeta(
    'daysOfWeek',
  );
  @override
  late final GeneratedColumn<String> daysOfWeek = GeneratedColumn<String>(
    'days_of_week',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _intervalDaysMeta = const VerificationMeta(
    'intervalDays',
  );
  @override
  late final GeneratedColumn<int> intervalDays = GeneratedColumn<int>(
    'interval_days',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dosageAmountMeta = const VerificationMeta(
    'dosageAmount',
  );
  @override
  late final GeneratedColumn<double> dosageAmount = GeneratedColumn<double>(
    'dosage_amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reminderOverrideMeta = const VerificationMeta(
    'reminderOverride',
  );
  @override
  late final GeneratedColumn<String> reminderOverride = GeneratedColumn<String>(
    'reminder_override',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    medicineId,
    timeOfDay,
    ianaTimezone,
    frequency,
    daysOfWeek,
    intervalDays,
    dosageAmount,
    reminderOverride,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'schedules';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScheduleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('medicine_id')) {
      context.handle(
        _medicineIdMeta,
        medicineId.isAcceptableOrUnknown(data['medicine_id']!, _medicineIdMeta),
      );
    } else if (isInserting) {
      context.missing(_medicineIdMeta);
    }
    if (data.containsKey('time_of_day')) {
      context.handle(
        _timeOfDayMeta,
        timeOfDay.isAcceptableOrUnknown(data['time_of_day']!, _timeOfDayMeta),
      );
    } else if (isInserting) {
      context.missing(_timeOfDayMeta);
    }
    if (data.containsKey('iana_timezone')) {
      context.handle(
        _ianaTimezoneMeta,
        ianaTimezone.isAcceptableOrUnknown(
          data['iana_timezone']!,
          _ianaTimezoneMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ianaTimezoneMeta);
    }
    if (data.containsKey('frequency')) {
      context.handle(
        _frequencyMeta,
        frequency.isAcceptableOrUnknown(data['frequency']!, _frequencyMeta),
      );
    } else if (isInserting) {
      context.missing(_frequencyMeta);
    }
    if (data.containsKey('days_of_week')) {
      context.handle(
        _daysOfWeekMeta,
        daysOfWeek.isAcceptableOrUnknown(
          data['days_of_week']!,
          _daysOfWeekMeta,
        ),
      );
    }
    if (data.containsKey('interval_days')) {
      context.handle(
        _intervalDaysMeta,
        intervalDays.isAcceptableOrUnknown(
          data['interval_days']!,
          _intervalDaysMeta,
        ),
      );
    }
    if (data.containsKey('dosage_amount')) {
      context.handle(
        _dosageAmountMeta,
        dosageAmount.isAcceptableOrUnknown(
          data['dosage_amount']!,
          _dosageAmountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dosageAmountMeta);
    }
    if (data.containsKey('reminder_override')) {
      context.handle(
        _reminderOverrideMeta,
        reminderOverride.isAcceptableOrUnknown(
          data['reminder_override']!,
          _reminderOverrideMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScheduleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScheduleRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      medicineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}medicine_id'],
      )!,
      timeOfDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_of_day'],
      )!,
      ianaTimezone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}iana_timezone'],
      )!,
      frequency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}frequency'],
      )!,
      daysOfWeek: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}days_of_week'],
      ),
      intervalDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interval_days'],
      ),
      dosageAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}dosage_amount'],
      )!,
      reminderOverride: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reminder_override'],
      ),
    );
  }

  @override
  $SchedulesTable createAlias(String alias) {
    return $SchedulesTable(attachedDatabase, alias);
  }
}

class ScheduleRow extends DataClass implements Insertable<ScheduleRow> {
  /// UUID v4, as text.
  final String id;

  /// The [Medicines] row this Schedule belongs to.
  ///
  /// `ON DELETE CASCADE` states AD-12's ownership in the schema: a Schedule has
  /// no life without its Medicine, and an orphan would be a reminder for a
  /// medicine the user cannot see. It is enforced rather than declared because
  /// `beforeOpen` turns `PRAGMA foreign_keys` on — SQLite ignores every foreign
  /// key without it. `DriftMedicineRepository.deleteMedicine` still deletes the
  /// Schedules explicitly, in the same transaction: the cascade is the
  /// database's guarantee for any path, and the explicit delete is the one this
  /// story's tests can watch.
  final String medicineId;

  /// The local wall-clock time, as 24-hour `HH:mm` (AD-6).
  final String timeOfDay;

  /// The IANA zone [timeOfDay] is read in — `Asia/Colombo` (AD-6).
  ///
  /// Per Schedule rather than read from the device, so a Schedule keeps its
  /// meaning when the user travels.
  final String ianaTimezone;

  /// One of `Frequency`'s four names (FR-4), as text.
  ///
  /// The enum's `name` rather than its `index`: an index would silently
  /// reinterpret every stored row the day a value is inserted into the middle
  /// of the enum, and there is no migration that could detect it.
  final String frequency;

  /// The days `Frequency.specificDays` names, as ascending `1`..`7` joined by
  /// commas — `1` is Monday, matching `DateTime.monday`.
  ///
  /// Null for every other frequency. Nullable rather than empty-string because
  /// "this frequency has no day set" and "this frequency has an empty day set"
  /// are different, and only the first is legal.
  final String? daysOfWeek;

  /// The interval `Frequency.everyNDays` counts in days. Null otherwise.
  ///
  /// Nullable, with no `CHECK` for the minimum of 2: the frequency/companion
  /// pairing is the domain's rule to enforce, not the schema's — three of the
  /// four frequencies leave this empty, so nothing in SQLite can tell whether
  /// a null here is correct.
  final int? intervalDays;

  /// How much is taken at this occurrence, defaulting at creation to the
  /// Medicine's amount. Stored per Schedule so "two in the morning, one at
  /// night" needs no second Medicine.
  final double dosageAmount;

  /// A per-Schedule escalation-window override, or null to inherit (AD-16).
  ///
  /// Opaque text until Story 1.6 gives the policy a type, so that the column
  /// exists before the policy does and the schema needs no further migration
  /// to gain it.
  final String? reminderOverride;
  const ScheduleRow({
    required this.id,
    required this.medicineId,
    required this.timeOfDay,
    required this.ianaTimezone,
    required this.frequency,
    this.daysOfWeek,
    this.intervalDays,
    required this.dosageAmount,
    this.reminderOverride,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['medicine_id'] = Variable<String>(medicineId);
    map['time_of_day'] = Variable<String>(timeOfDay);
    map['iana_timezone'] = Variable<String>(ianaTimezone);
    map['frequency'] = Variable<String>(frequency);
    if (!nullToAbsent || daysOfWeek != null) {
      map['days_of_week'] = Variable<String>(daysOfWeek);
    }
    if (!nullToAbsent || intervalDays != null) {
      map['interval_days'] = Variable<int>(intervalDays);
    }
    map['dosage_amount'] = Variable<double>(dosageAmount);
    if (!nullToAbsent || reminderOverride != null) {
      map['reminder_override'] = Variable<String>(reminderOverride);
    }
    return map;
  }

  SchedulesCompanion toCompanion(bool nullToAbsent) {
    return SchedulesCompanion(
      id: Value(id),
      medicineId: Value(medicineId),
      timeOfDay: Value(timeOfDay),
      ianaTimezone: Value(ianaTimezone),
      frequency: Value(frequency),
      daysOfWeek: daysOfWeek == null && nullToAbsent
          ? const Value.absent()
          : Value(daysOfWeek),
      intervalDays: intervalDays == null && nullToAbsent
          ? const Value.absent()
          : Value(intervalDays),
      dosageAmount: Value(dosageAmount),
      reminderOverride: reminderOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(reminderOverride),
    );
  }

  factory ScheduleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScheduleRow(
      id: serializer.fromJson<String>(json['id']),
      medicineId: serializer.fromJson<String>(json['medicineId']),
      timeOfDay: serializer.fromJson<String>(json['timeOfDay']),
      ianaTimezone: serializer.fromJson<String>(json['ianaTimezone']),
      frequency: serializer.fromJson<String>(json['frequency']),
      daysOfWeek: serializer.fromJson<String?>(json['daysOfWeek']),
      intervalDays: serializer.fromJson<int?>(json['intervalDays']),
      dosageAmount: serializer.fromJson<double>(json['dosageAmount']),
      reminderOverride: serializer.fromJson<String?>(json['reminderOverride']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'medicineId': serializer.toJson<String>(medicineId),
      'timeOfDay': serializer.toJson<String>(timeOfDay),
      'ianaTimezone': serializer.toJson<String>(ianaTimezone),
      'frequency': serializer.toJson<String>(frequency),
      'daysOfWeek': serializer.toJson<String?>(daysOfWeek),
      'intervalDays': serializer.toJson<int?>(intervalDays),
      'dosageAmount': serializer.toJson<double>(dosageAmount),
      'reminderOverride': serializer.toJson<String?>(reminderOverride),
    };
  }

  ScheduleRow copyWith({
    String? id,
    String? medicineId,
    String? timeOfDay,
    String? ianaTimezone,
    String? frequency,
    Value<String?> daysOfWeek = const Value.absent(),
    Value<int?> intervalDays = const Value.absent(),
    double? dosageAmount,
    Value<String?> reminderOverride = const Value.absent(),
  }) => ScheduleRow(
    id: id ?? this.id,
    medicineId: medicineId ?? this.medicineId,
    timeOfDay: timeOfDay ?? this.timeOfDay,
    ianaTimezone: ianaTimezone ?? this.ianaTimezone,
    frequency: frequency ?? this.frequency,
    daysOfWeek: daysOfWeek.present ? daysOfWeek.value : this.daysOfWeek,
    intervalDays: intervalDays.present ? intervalDays.value : this.intervalDays,
    dosageAmount: dosageAmount ?? this.dosageAmount,
    reminderOverride: reminderOverride.present
        ? reminderOverride.value
        : this.reminderOverride,
  );
  ScheduleRow copyWithCompanion(SchedulesCompanion data) {
    return ScheduleRow(
      id: data.id.present ? data.id.value : this.id,
      medicineId: data.medicineId.present
          ? data.medicineId.value
          : this.medicineId,
      timeOfDay: data.timeOfDay.present ? data.timeOfDay.value : this.timeOfDay,
      ianaTimezone: data.ianaTimezone.present
          ? data.ianaTimezone.value
          : this.ianaTimezone,
      frequency: data.frequency.present ? data.frequency.value : this.frequency,
      daysOfWeek: data.daysOfWeek.present
          ? data.daysOfWeek.value
          : this.daysOfWeek,
      intervalDays: data.intervalDays.present
          ? data.intervalDays.value
          : this.intervalDays,
      dosageAmount: data.dosageAmount.present
          ? data.dosageAmount.value
          : this.dosageAmount,
      reminderOverride: data.reminderOverride.present
          ? data.reminderOverride.value
          : this.reminderOverride,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScheduleRow(')
          ..write('id: $id, ')
          ..write('medicineId: $medicineId, ')
          ..write('timeOfDay: $timeOfDay, ')
          ..write('ianaTimezone: $ianaTimezone, ')
          ..write('frequency: $frequency, ')
          ..write('daysOfWeek: $daysOfWeek, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('dosageAmount: $dosageAmount, ')
          ..write('reminderOverride: $reminderOverride')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    medicineId,
    timeOfDay,
    ianaTimezone,
    frequency,
    daysOfWeek,
    intervalDays,
    dosageAmount,
    reminderOverride,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScheduleRow &&
          other.id == this.id &&
          other.medicineId == this.medicineId &&
          other.timeOfDay == this.timeOfDay &&
          other.ianaTimezone == this.ianaTimezone &&
          other.frequency == this.frequency &&
          other.daysOfWeek == this.daysOfWeek &&
          other.intervalDays == this.intervalDays &&
          other.dosageAmount == this.dosageAmount &&
          other.reminderOverride == this.reminderOverride);
}

class SchedulesCompanion extends UpdateCompanion<ScheduleRow> {
  final Value<String> id;
  final Value<String> medicineId;
  final Value<String> timeOfDay;
  final Value<String> ianaTimezone;
  final Value<String> frequency;
  final Value<String?> daysOfWeek;
  final Value<int?> intervalDays;
  final Value<double> dosageAmount;
  final Value<String?> reminderOverride;
  final Value<int> rowid;
  const SchedulesCompanion({
    this.id = const Value.absent(),
    this.medicineId = const Value.absent(),
    this.timeOfDay = const Value.absent(),
    this.ianaTimezone = const Value.absent(),
    this.frequency = const Value.absent(),
    this.daysOfWeek = const Value.absent(),
    this.intervalDays = const Value.absent(),
    this.dosageAmount = const Value.absent(),
    this.reminderOverride = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SchedulesCompanion.insert({
    required String id,
    required String medicineId,
    required String timeOfDay,
    required String ianaTimezone,
    required String frequency,
    this.daysOfWeek = const Value.absent(),
    this.intervalDays = const Value.absent(),
    required double dosageAmount,
    this.reminderOverride = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       medicineId = Value(medicineId),
       timeOfDay = Value(timeOfDay),
       ianaTimezone = Value(ianaTimezone),
       frequency = Value(frequency),
       dosageAmount = Value(dosageAmount);
  static Insertable<ScheduleRow> custom({
    Expression<String>? id,
    Expression<String>? medicineId,
    Expression<String>? timeOfDay,
    Expression<String>? ianaTimezone,
    Expression<String>? frequency,
    Expression<String>? daysOfWeek,
    Expression<int>? intervalDays,
    Expression<double>? dosageAmount,
    Expression<String>? reminderOverride,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (medicineId != null) 'medicine_id': medicineId,
      if (timeOfDay != null) 'time_of_day': timeOfDay,
      if (ianaTimezone != null) 'iana_timezone': ianaTimezone,
      if (frequency != null) 'frequency': frequency,
      if (daysOfWeek != null) 'days_of_week': daysOfWeek,
      if (intervalDays != null) 'interval_days': intervalDays,
      if (dosageAmount != null) 'dosage_amount': dosageAmount,
      if (reminderOverride != null) 'reminder_override': reminderOverride,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SchedulesCompanion copyWith({
    Value<String>? id,
    Value<String>? medicineId,
    Value<String>? timeOfDay,
    Value<String>? ianaTimezone,
    Value<String>? frequency,
    Value<String?>? daysOfWeek,
    Value<int?>? intervalDays,
    Value<double>? dosageAmount,
    Value<String?>? reminderOverride,
    Value<int>? rowid,
  }) {
    return SchedulesCompanion(
      id: id ?? this.id,
      medicineId: medicineId ?? this.medicineId,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      ianaTimezone: ianaTimezone ?? this.ianaTimezone,
      frequency: frequency ?? this.frequency,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      intervalDays: intervalDays ?? this.intervalDays,
      dosageAmount: dosageAmount ?? this.dosageAmount,
      reminderOverride: reminderOverride ?? this.reminderOverride,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (medicineId.present) {
      map['medicine_id'] = Variable<String>(medicineId.value);
    }
    if (timeOfDay.present) {
      map['time_of_day'] = Variable<String>(timeOfDay.value);
    }
    if (ianaTimezone.present) {
      map['iana_timezone'] = Variable<String>(ianaTimezone.value);
    }
    if (frequency.present) {
      map['frequency'] = Variable<String>(frequency.value);
    }
    if (daysOfWeek.present) {
      map['days_of_week'] = Variable<String>(daysOfWeek.value);
    }
    if (intervalDays.present) {
      map['interval_days'] = Variable<int>(intervalDays.value);
    }
    if (dosageAmount.present) {
      map['dosage_amount'] = Variable<double>(dosageAmount.value);
    }
    if (reminderOverride.present) {
      map['reminder_override'] = Variable<String>(reminderOverride.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SchedulesCompanion(')
          ..write('id: $id, ')
          ..write('medicineId: $medicineId, ')
          ..write('timeOfDay: $timeOfDay, ')
          ..write('ianaTimezone: $ianaTimezone, ')
          ..write('frequency: $frequency, ')
          ..write('daysOfWeek: $daysOfWeek, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('dosageAmount: $dosageAmount, ')
          ..write('reminderOverride: $reminderOverride, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DosesTable extends Doses with TableInfo<$DosesTable, DoseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DosesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scheduleIdMeta = const VerificationMeta(
    'scheduleId',
  );
  @override
  late final GeneratedColumn<String> scheduleId = GeneratedColumn<String>(
    'schedule_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES schedules (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _medicineIdMeta = const VerificationMeta(
    'medicineId',
  );
  @override
  late final GeneratedColumn<String> medicineId = GeneratedColumn<String>(
    'medicine_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES medicines (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _scheduledLocalMeta = const VerificationMeta(
    'scheduledLocal',
  );
  @override
  late final GeneratedColumn<String> scheduledLocal = GeneratedColumn<String>(
    'scheduled_local',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ianaTimezoneMeta = const VerificationMeta(
    'ianaTimezone',
  );
  @override
  late final GeneratedColumn<String> ianaTimezone = GeneratedColumn<String>(
    'iana_timezone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scheduledUtcMeta = const VerificationMeta(
    'scheduledUtc',
  );
  @override
  late final GeneratedColumn<String> scheduledUtc = GeneratedColumn<String>(
    'scheduled_utc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _takenAtMeta = const VerificationMeta(
    'takenAt',
  );
  @override
  late final GeneratedColumn<String> takenAt = GeneratedColumn<String>(
    'taken_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _skippedAtMeta = const VerificationMeta(
    'skippedAt',
  );
  @override
  late final GeneratedColumn<String> skippedAt = GeneratedColumn<String>(
    'skipped_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _snoozedUntilMeta = const VerificationMeta(
    'snoozedUntil',
  );
  @override
  late final GeneratedColumn<String> snoozedUntil = GeneratedColumn<String>(
    'snoozed_until',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _snoozeCountMeta = const VerificationMeta(
    'snoozeCount',
  );
  @override
  late final GeneratedColumn<int> snoozeCount = GeneratedColumn<int>(
    'snooze_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _medicineNameMeta = const VerificationMeta(
    'medicineName',
  );
  @override
  late final GeneratedColumn<String> medicineName = GeneratedColumn<String>(
    'medicine_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dosageAmountMeta = const VerificationMeta(
    'dosageAmount',
  );
  @override
  late final GeneratedColumn<double> dosageAmount = GeneratedColumn<double>(
    'dosage_amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dosageUnitMeta = const VerificationMeta(
    'dosageUnit',
  );
  @override
  late final GeneratedColumn<String> dosageUnit = GeneratedColumn<String>(
    'dosage_unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formMeta = const VerificationMeta('form');
  @override
  late final GeneratedColumn<String> form = GeneratedColumn<String>(
    'form',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _escalationWindowMinutesMeta =
      const VerificationMeta('escalationWindowMinutes');
  @override
  late final GeneratedColumn<int> escalationWindowMinutes =
      GeneratedColumn<int>(
        'escalation_window_minutes',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _followUpOffsetsMinutesMeta =
      const VerificationMeta('followUpOffsetsMinutes');
  @override
  late final GeneratedColumn<String> followUpOffsetsMinutes =
      GeneratedColumn<String>(
        'follow_up_offsets_minutes',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    scheduleId,
    medicineId,
    scheduledLocal,
    ianaTimezone,
    scheduledUtc,
    takenAt,
    skippedAt,
    snoozedUntil,
    snoozeCount,
    medicineName,
    dosageAmount,
    dosageUnit,
    form,
    escalationWindowMinutes,
    followUpOffsetsMinutes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'doses';
  @override
  VerificationContext validateIntegrity(
    Insertable<DoseRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('schedule_id')) {
      context.handle(
        _scheduleIdMeta,
        scheduleId.isAcceptableOrUnknown(data['schedule_id']!, _scheduleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scheduleIdMeta);
    }
    if (data.containsKey('medicine_id')) {
      context.handle(
        _medicineIdMeta,
        medicineId.isAcceptableOrUnknown(data['medicine_id']!, _medicineIdMeta),
      );
    } else if (isInserting) {
      context.missing(_medicineIdMeta);
    }
    if (data.containsKey('scheduled_local')) {
      context.handle(
        _scheduledLocalMeta,
        scheduledLocal.isAcceptableOrUnknown(
          data['scheduled_local']!,
          _scheduledLocalMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledLocalMeta);
    }
    if (data.containsKey('iana_timezone')) {
      context.handle(
        _ianaTimezoneMeta,
        ianaTimezone.isAcceptableOrUnknown(
          data['iana_timezone']!,
          _ianaTimezoneMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ianaTimezoneMeta);
    }
    if (data.containsKey('scheduled_utc')) {
      context.handle(
        _scheduledUtcMeta,
        scheduledUtc.isAcceptableOrUnknown(
          data['scheduled_utc']!,
          _scheduledUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledUtcMeta);
    }
    if (data.containsKey('taken_at')) {
      context.handle(
        _takenAtMeta,
        takenAt.isAcceptableOrUnknown(data['taken_at']!, _takenAtMeta),
      );
    }
    if (data.containsKey('skipped_at')) {
      context.handle(
        _skippedAtMeta,
        skippedAt.isAcceptableOrUnknown(data['skipped_at']!, _skippedAtMeta),
      );
    }
    if (data.containsKey('snoozed_until')) {
      context.handle(
        _snoozedUntilMeta,
        snoozedUntil.isAcceptableOrUnknown(
          data['snoozed_until']!,
          _snoozedUntilMeta,
        ),
      );
    }
    if (data.containsKey('snooze_count')) {
      context.handle(
        _snoozeCountMeta,
        snoozeCount.isAcceptableOrUnknown(
          data['snooze_count']!,
          _snoozeCountMeta,
        ),
      );
    }
    if (data.containsKey('medicine_name')) {
      context.handle(
        _medicineNameMeta,
        medicineName.isAcceptableOrUnknown(
          data['medicine_name']!,
          _medicineNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_medicineNameMeta);
    }
    if (data.containsKey('dosage_amount')) {
      context.handle(
        _dosageAmountMeta,
        dosageAmount.isAcceptableOrUnknown(
          data['dosage_amount']!,
          _dosageAmountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dosageAmountMeta);
    }
    if (data.containsKey('dosage_unit')) {
      context.handle(
        _dosageUnitMeta,
        dosageUnit.isAcceptableOrUnknown(data['dosage_unit']!, _dosageUnitMeta),
      );
    } else if (isInserting) {
      context.missing(_dosageUnitMeta);
    }
    if (data.containsKey('form')) {
      context.handle(
        _formMeta,
        form.isAcceptableOrUnknown(data['form']!, _formMeta),
      );
    } else if (isInserting) {
      context.missing(_formMeta);
    }
    if (data.containsKey('escalation_window_minutes')) {
      context.handle(
        _escalationWindowMinutesMeta,
        escalationWindowMinutes.isAcceptableOrUnknown(
          data['escalation_window_minutes']!,
          _escalationWindowMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_escalationWindowMinutesMeta);
    }
    if (data.containsKey('follow_up_offsets_minutes')) {
      context.handle(
        _followUpOffsetsMinutesMeta,
        followUpOffsetsMinutes.isAcceptableOrUnknown(
          data['follow_up_offsets_minutes']!,
          _followUpOffsetsMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_followUpOffsetsMinutesMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {scheduleId, scheduledLocal},
  ];
  @override
  DoseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DoseRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      scheduleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}schedule_id'],
      )!,
      medicineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}medicine_id'],
      )!,
      scheduledLocal: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scheduled_local'],
      )!,
      ianaTimezone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}iana_timezone'],
      )!,
      scheduledUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scheduled_utc'],
      )!,
      takenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}taken_at'],
      ),
      skippedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}skipped_at'],
      ),
      snoozedUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snoozed_until'],
      ),
      snoozeCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}snooze_count'],
      )!,
      medicineName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}medicine_name'],
      )!,
      dosageAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}dosage_amount'],
      )!,
      dosageUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dosage_unit'],
      )!,
      form: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}form'],
      )!,
      escalationWindowMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}escalation_window_minutes'],
      )!,
      followUpOffsetsMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}follow_up_offsets_minutes'],
      )!,
    );
  }

  @override
  $DosesTable createAlias(String alias) {
    return $DosesTable(attachedDatabase, alias);
  }
}

class DoseRow extends DataClass implements Insertable<DoseRow> {
  /// Deterministic per the spine's Identifiers convention --
  /// `"{scheduleId}:{scheduledLocal ISO-8601}"` (AD-10). Minted by `Dose`
  /// itself and written as given: unlike [Medicines]/[Schedules],
  /// `DriftDoseRepository` mints no identity of its own.
  final String id;

  /// The [Schedules] row this Dose was generated from.
  final String scheduleId;

  /// The [Medicines] row this Dose belongs to, denormalised from the Schedule
  /// rather than read through it -- AD-20's Escalation Window formula measures
  /// the interval to the next dose of the *same Medicine across all its
  /// Schedules*, a question a join on [scheduleId] alone cannot answer.
  final String medicineId;

  /// The wall-clock time this occurrence falls at, with no zone of its own
  /// (AD-6) -- `Dose.scheduledLocal`, as ISO-8601 text with no offset.
  final String scheduledLocal;

  /// The IANA zone [scheduledLocal] is read in -- `Dose.ianaTimezone`.
  final String ianaTimezone;

  /// [scheduledLocal] resolved in [ianaTimezone], as a UTC instant --
  /// `Dose.scheduledAt`, AD-6's one sanctioned UTC column, denormalised for
  /// ordering and range queries only. Never the stored truth: [scheduledLocal]
  /// plus [ianaTimezone] remains that, exactly as AD-6 requires.
  final String scheduledUtc;

  /// When the user recorded taking this Dose, or null. Written only by
  /// `DoseRecorder` (AD-4), which does not exist before Epic 2 -- the column
  /// exists now because a complete row needs somewhere to hold the fact once
  /// `DoseRecorder` does.
  final String? takenAt;

  /// When the user recorded skipping this Dose, or null. See [takenAt].
  final String? skippedAt;

  /// The instant a live snooze runs out, or null. See [takenAt].
  final String? snoozedUntil;

  /// How many times this Dose has been snoozed. Defaults to 0, matching
  /// `Dose.snoozeCount`'s own default.
  final int snoozeCount;

  /// The Medicine's name, frozen at generation (AD-11) so History reads this
  /// row instead of a live join a later rename could change underneath it.
  final String medicineName;

  /// The dose amount, frozen at generation (AD-11). See [medicineName].
  final double dosageAmount;

  /// The dose unit, frozen at generation (AD-11). See [medicineName].
  final String dosageUnit;

  /// Tablet, capsule, drops -- frozen at generation (AD-11). See
  /// [medicineName]. The spine's ERD mermaid block omits this column from
  /// `DOSE`; that is a diagram error the spec names explicitly, not a second
  /// source of truth -- AD-11's prose lists all four frozen fields.
  final String form;

  /// The Escalation Window's length in minutes, resolved and frozen at
  /// generation (AD-16) -- `resolve()` reads this, never a live
  /// `ReminderSettings` value.
  final int escalationWindowMinutes;

  /// The follow-up offsets in minutes, frozen at generation (AD-16), as
  /// comma-separated text in chain order. Order-preserving rather than sorted
  /// like [Schedules.daysOfWeek]: these are offsets along one escalation
  /// chain, not a set.
  final String followUpOffsetsMinutes;
  const DoseRow({
    required this.id,
    required this.scheduleId,
    required this.medicineId,
    required this.scheduledLocal,
    required this.ianaTimezone,
    required this.scheduledUtc,
    this.takenAt,
    this.skippedAt,
    this.snoozedUntil,
    required this.snoozeCount,
    required this.medicineName,
    required this.dosageAmount,
    required this.dosageUnit,
    required this.form,
    required this.escalationWindowMinutes,
    required this.followUpOffsetsMinutes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['schedule_id'] = Variable<String>(scheduleId);
    map['medicine_id'] = Variable<String>(medicineId);
    map['scheduled_local'] = Variable<String>(scheduledLocal);
    map['iana_timezone'] = Variable<String>(ianaTimezone);
    map['scheduled_utc'] = Variable<String>(scheduledUtc);
    if (!nullToAbsent || takenAt != null) {
      map['taken_at'] = Variable<String>(takenAt);
    }
    if (!nullToAbsent || skippedAt != null) {
      map['skipped_at'] = Variable<String>(skippedAt);
    }
    if (!nullToAbsent || snoozedUntil != null) {
      map['snoozed_until'] = Variable<String>(snoozedUntil);
    }
    map['snooze_count'] = Variable<int>(snoozeCount);
    map['medicine_name'] = Variable<String>(medicineName);
    map['dosage_amount'] = Variable<double>(dosageAmount);
    map['dosage_unit'] = Variable<String>(dosageUnit);
    map['form'] = Variable<String>(form);
    map['escalation_window_minutes'] = Variable<int>(escalationWindowMinutes);
    map['follow_up_offsets_minutes'] = Variable<String>(followUpOffsetsMinutes);
    return map;
  }

  DosesCompanion toCompanion(bool nullToAbsent) {
    return DosesCompanion(
      id: Value(id),
      scheduleId: Value(scheduleId),
      medicineId: Value(medicineId),
      scheduledLocal: Value(scheduledLocal),
      ianaTimezone: Value(ianaTimezone),
      scheduledUtc: Value(scheduledUtc),
      takenAt: takenAt == null && nullToAbsent
          ? const Value.absent()
          : Value(takenAt),
      skippedAt: skippedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(skippedAt),
      snoozedUntil: snoozedUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(snoozedUntil),
      snoozeCount: Value(snoozeCount),
      medicineName: Value(medicineName),
      dosageAmount: Value(dosageAmount),
      dosageUnit: Value(dosageUnit),
      form: Value(form),
      escalationWindowMinutes: Value(escalationWindowMinutes),
      followUpOffsetsMinutes: Value(followUpOffsetsMinutes),
    );
  }

  factory DoseRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DoseRow(
      id: serializer.fromJson<String>(json['id']),
      scheduleId: serializer.fromJson<String>(json['scheduleId']),
      medicineId: serializer.fromJson<String>(json['medicineId']),
      scheduledLocal: serializer.fromJson<String>(json['scheduledLocal']),
      ianaTimezone: serializer.fromJson<String>(json['ianaTimezone']),
      scheduledUtc: serializer.fromJson<String>(json['scheduledUtc']),
      takenAt: serializer.fromJson<String?>(json['takenAt']),
      skippedAt: serializer.fromJson<String?>(json['skippedAt']),
      snoozedUntil: serializer.fromJson<String?>(json['snoozedUntil']),
      snoozeCount: serializer.fromJson<int>(json['snoozeCount']),
      medicineName: serializer.fromJson<String>(json['medicineName']),
      dosageAmount: serializer.fromJson<double>(json['dosageAmount']),
      dosageUnit: serializer.fromJson<String>(json['dosageUnit']),
      form: serializer.fromJson<String>(json['form']),
      escalationWindowMinutes: serializer.fromJson<int>(
        json['escalationWindowMinutes'],
      ),
      followUpOffsetsMinutes: serializer.fromJson<String>(
        json['followUpOffsetsMinutes'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'scheduleId': serializer.toJson<String>(scheduleId),
      'medicineId': serializer.toJson<String>(medicineId),
      'scheduledLocal': serializer.toJson<String>(scheduledLocal),
      'ianaTimezone': serializer.toJson<String>(ianaTimezone),
      'scheduledUtc': serializer.toJson<String>(scheduledUtc),
      'takenAt': serializer.toJson<String?>(takenAt),
      'skippedAt': serializer.toJson<String?>(skippedAt),
      'snoozedUntil': serializer.toJson<String?>(snoozedUntil),
      'snoozeCount': serializer.toJson<int>(snoozeCount),
      'medicineName': serializer.toJson<String>(medicineName),
      'dosageAmount': serializer.toJson<double>(dosageAmount),
      'dosageUnit': serializer.toJson<String>(dosageUnit),
      'form': serializer.toJson<String>(form),
      'escalationWindowMinutes': serializer.toJson<int>(
        escalationWindowMinutes,
      ),
      'followUpOffsetsMinutes': serializer.toJson<String>(
        followUpOffsetsMinutes,
      ),
    };
  }

  DoseRow copyWith({
    String? id,
    String? scheduleId,
    String? medicineId,
    String? scheduledLocal,
    String? ianaTimezone,
    String? scheduledUtc,
    Value<String?> takenAt = const Value.absent(),
    Value<String?> skippedAt = const Value.absent(),
    Value<String?> snoozedUntil = const Value.absent(),
    int? snoozeCount,
    String? medicineName,
    double? dosageAmount,
    String? dosageUnit,
    String? form,
    int? escalationWindowMinutes,
    String? followUpOffsetsMinutes,
  }) => DoseRow(
    id: id ?? this.id,
    scheduleId: scheduleId ?? this.scheduleId,
    medicineId: medicineId ?? this.medicineId,
    scheduledLocal: scheduledLocal ?? this.scheduledLocal,
    ianaTimezone: ianaTimezone ?? this.ianaTimezone,
    scheduledUtc: scheduledUtc ?? this.scheduledUtc,
    takenAt: takenAt.present ? takenAt.value : this.takenAt,
    skippedAt: skippedAt.present ? skippedAt.value : this.skippedAt,
    snoozedUntil: snoozedUntil.present ? snoozedUntil.value : this.snoozedUntil,
    snoozeCount: snoozeCount ?? this.snoozeCount,
    medicineName: medicineName ?? this.medicineName,
    dosageAmount: dosageAmount ?? this.dosageAmount,
    dosageUnit: dosageUnit ?? this.dosageUnit,
    form: form ?? this.form,
    escalationWindowMinutes:
        escalationWindowMinutes ?? this.escalationWindowMinutes,
    followUpOffsetsMinutes:
        followUpOffsetsMinutes ?? this.followUpOffsetsMinutes,
  );
  DoseRow copyWithCompanion(DosesCompanion data) {
    return DoseRow(
      id: data.id.present ? data.id.value : this.id,
      scheduleId: data.scheduleId.present
          ? data.scheduleId.value
          : this.scheduleId,
      medicineId: data.medicineId.present
          ? data.medicineId.value
          : this.medicineId,
      scheduledLocal: data.scheduledLocal.present
          ? data.scheduledLocal.value
          : this.scheduledLocal,
      ianaTimezone: data.ianaTimezone.present
          ? data.ianaTimezone.value
          : this.ianaTimezone,
      scheduledUtc: data.scheduledUtc.present
          ? data.scheduledUtc.value
          : this.scheduledUtc,
      takenAt: data.takenAt.present ? data.takenAt.value : this.takenAt,
      skippedAt: data.skippedAt.present ? data.skippedAt.value : this.skippedAt,
      snoozedUntil: data.snoozedUntil.present
          ? data.snoozedUntil.value
          : this.snoozedUntil,
      snoozeCount: data.snoozeCount.present
          ? data.snoozeCount.value
          : this.snoozeCount,
      medicineName: data.medicineName.present
          ? data.medicineName.value
          : this.medicineName,
      dosageAmount: data.dosageAmount.present
          ? data.dosageAmount.value
          : this.dosageAmount,
      dosageUnit: data.dosageUnit.present
          ? data.dosageUnit.value
          : this.dosageUnit,
      form: data.form.present ? data.form.value : this.form,
      escalationWindowMinutes: data.escalationWindowMinutes.present
          ? data.escalationWindowMinutes.value
          : this.escalationWindowMinutes,
      followUpOffsetsMinutes: data.followUpOffsetsMinutes.present
          ? data.followUpOffsetsMinutes.value
          : this.followUpOffsetsMinutes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DoseRow(')
          ..write('id: $id, ')
          ..write('scheduleId: $scheduleId, ')
          ..write('medicineId: $medicineId, ')
          ..write('scheduledLocal: $scheduledLocal, ')
          ..write('ianaTimezone: $ianaTimezone, ')
          ..write('scheduledUtc: $scheduledUtc, ')
          ..write('takenAt: $takenAt, ')
          ..write('skippedAt: $skippedAt, ')
          ..write('snoozedUntil: $snoozedUntil, ')
          ..write('snoozeCount: $snoozeCount, ')
          ..write('medicineName: $medicineName, ')
          ..write('dosageAmount: $dosageAmount, ')
          ..write('dosageUnit: $dosageUnit, ')
          ..write('form: $form, ')
          ..write('escalationWindowMinutes: $escalationWindowMinutes, ')
          ..write('followUpOffsetsMinutes: $followUpOffsetsMinutes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    scheduleId,
    medicineId,
    scheduledLocal,
    ianaTimezone,
    scheduledUtc,
    takenAt,
    skippedAt,
    snoozedUntil,
    snoozeCount,
    medicineName,
    dosageAmount,
    dosageUnit,
    form,
    escalationWindowMinutes,
    followUpOffsetsMinutes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DoseRow &&
          other.id == this.id &&
          other.scheduleId == this.scheduleId &&
          other.medicineId == this.medicineId &&
          other.scheduledLocal == this.scheduledLocal &&
          other.ianaTimezone == this.ianaTimezone &&
          other.scheduledUtc == this.scheduledUtc &&
          other.takenAt == this.takenAt &&
          other.skippedAt == this.skippedAt &&
          other.snoozedUntil == this.snoozedUntil &&
          other.snoozeCount == this.snoozeCount &&
          other.medicineName == this.medicineName &&
          other.dosageAmount == this.dosageAmount &&
          other.dosageUnit == this.dosageUnit &&
          other.form == this.form &&
          other.escalationWindowMinutes == this.escalationWindowMinutes &&
          other.followUpOffsetsMinutes == this.followUpOffsetsMinutes);
}

class DosesCompanion extends UpdateCompanion<DoseRow> {
  final Value<String> id;
  final Value<String> scheduleId;
  final Value<String> medicineId;
  final Value<String> scheduledLocal;
  final Value<String> ianaTimezone;
  final Value<String> scheduledUtc;
  final Value<String?> takenAt;
  final Value<String?> skippedAt;
  final Value<String?> snoozedUntil;
  final Value<int> snoozeCount;
  final Value<String> medicineName;
  final Value<double> dosageAmount;
  final Value<String> dosageUnit;
  final Value<String> form;
  final Value<int> escalationWindowMinutes;
  final Value<String> followUpOffsetsMinutes;
  final Value<int> rowid;
  const DosesCompanion({
    this.id = const Value.absent(),
    this.scheduleId = const Value.absent(),
    this.medicineId = const Value.absent(),
    this.scheduledLocal = const Value.absent(),
    this.ianaTimezone = const Value.absent(),
    this.scheduledUtc = const Value.absent(),
    this.takenAt = const Value.absent(),
    this.skippedAt = const Value.absent(),
    this.snoozedUntil = const Value.absent(),
    this.snoozeCount = const Value.absent(),
    this.medicineName = const Value.absent(),
    this.dosageAmount = const Value.absent(),
    this.dosageUnit = const Value.absent(),
    this.form = const Value.absent(),
    this.escalationWindowMinutes = const Value.absent(),
    this.followUpOffsetsMinutes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DosesCompanion.insert({
    required String id,
    required String scheduleId,
    required String medicineId,
    required String scheduledLocal,
    required String ianaTimezone,
    required String scheduledUtc,
    this.takenAt = const Value.absent(),
    this.skippedAt = const Value.absent(),
    this.snoozedUntil = const Value.absent(),
    this.snoozeCount = const Value.absent(),
    required String medicineName,
    required double dosageAmount,
    required String dosageUnit,
    required String form,
    required int escalationWindowMinutes,
    required String followUpOffsetsMinutes,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       scheduleId = Value(scheduleId),
       medicineId = Value(medicineId),
       scheduledLocal = Value(scheduledLocal),
       ianaTimezone = Value(ianaTimezone),
       scheduledUtc = Value(scheduledUtc),
       medicineName = Value(medicineName),
       dosageAmount = Value(dosageAmount),
       dosageUnit = Value(dosageUnit),
       form = Value(form),
       escalationWindowMinutes = Value(escalationWindowMinutes),
       followUpOffsetsMinutes = Value(followUpOffsetsMinutes);
  static Insertable<DoseRow> custom({
    Expression<String>? id,
    Expression<String>? scheduleId,
    Expression<String>? medicineId,
    Expression<String>? scheduledLocal,
    Expression<String>? ianaTimezone,
    Expression<String>? scheduledUtc,
    Expression<String>? takenAt,
    Expression<String>? skippedAt,
    Expression<String>? snoozedUntil,
    Expression<int>? snoozeCount,
    Expression<String>? medicineName,
    Expression<double>? dosageAmount,
    Expression<String>? dosageUnit,
    Expression<String>? form,
    Expression<int>? escalationWindowMinutes,
    Expression<String>? followUpOffsetsMinutes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scheduleId != null) 'schedule_id': scheduleId,
      if (medicineId != null) 'medicine_id': medicineId,
      if (scheduledLocal != null) 'scheduled_local': scheduledLocal,
      if (ianaTimezone != null) 'iana_timezone': ianaTimezone,
      if (scheduledUtc != null) 'scheduled_utc': scheduledUtc,
      if (takenAt != null) 'taken_at': takenAt,
      if (skippedAt != null) 'skipped_at': skippedAt,
      if (snoozedUntil != null) 'snoozed_until': snoozedUntil,
      if (snoozeCount != null) 'snooze_count': snoozeCount,
      if (medicineName != null) 'medicine_name': medicineName,
      if (dosageAmount != null) 'dosage_amount': dosageAmount,
      if (dosageUnit != null) 'dosage_unit': dosageUnit,
      if (form != null) 'form': form,
      if (escalationWindowMinutes != null)
        'escalation_window_minutes': escalationWindowMinutes,
      if (followUpOffsetsMinutes != null)
        'follow_up_offsets_minutes': followUpOffsetsMinutes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DosesCompanion copyWith({
    Value<String>? id,
    Value<String>? scheduleId,
    Value<String>? medicineId,
    Value<String>? scheduledLocal,
    Value<String>? ianaTimezone,
    Value<String>? scheduledUtc,
    Value<String?>? takenAt,
    Value<String?>? skippedAt,
    Value<String?>? snoozedUntil,
    Value<int>? snoozeCount,
    Value<String>? medicineName,
    Value<double>? dosageAmount,
    Value<String>? dosageUnit,
    Value<String>? form,
    Value<int>? escalationWindowMinutes,
    Value<String>? followUpOffsetsMinutes,
    Value<int>? rowid,
  }) {
    return DosesCompanion(
      id: id ?? this.id,
      scheduleId: scheduleId ?? this.scheduleId,
      medicineId: medicineId ?? this.medicineId,
      scheduledLocal: scheduledLocal ?? this.scheduledLocal,
      ianaTimezone: ianaTimezone ?? this.ianaTimezone,
      scheduledUtc: scheduledUtc ?? this.scheduledUtc,
      takenAt: takenAt ?? this.takenAt,
      skippedAt: skippedAt ?? this.skippedAt,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      snoozeCount: snoozeCount ?? this.snoozeCount,
      medicineName: medicineName ?? this.medicineName,
      dosageAmount: dosageAmount ?? this.dosageAmount,
      dosageUnit: dosageUnit ?? this.dosageUnit,
      form: form ?? this.form,
      escalationWindowMinutes:
          escalationWindowMinutes ?? this.escalationWindowMinutes,
      followUpOffsetsMinutes:
          followUpOffsetsMinutes ?? this.followUpOffsetsMinutes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (scheduleId.present) {
      map['schedule_id'] = Variable<String>(scheduleId.value);
    }
    if (medicineId.present) {
      map['medicine_id'] = Variable<String>(medicineId.value);
    }
    if (scheduledLocal.present) {
      map['scheduled_local'] = Variable<String>(scheduledLocal.value);
    }
    if (ianaTimezone.present) {
      map['iana_timezone'] = Variable<String>(ianaTimezone.value);
    }
    if (scheduledUtc.present) {
      map['scheduled_utc'] = Variable<String>(scheduledUtc.value);
    }
    if (takenAt.present) {
      map['taken_at'] = Variable<String>(takenAt.value);
    }
    if (skippedAt.present) {
      map['skipped_at'] = Variable<String>(skippedAt.value);
    }
    if (snoozedUntil.present) {
      map['snoozed_until'] = Variable<String>(snoozedUntil.value);
    }
    if (snoozeCount.present) {
      map['snooze_count'] = Variable<int>(snoozeCount.value);
    }
    if (medicineName.present) {
      map['medicine_name'] = Variable<String>(medicineName.value);
    }
    if (dosageAmount.present) {
      map['dosage_amount'] = Variable<double>(dosageAmount.value);
    }
    if (dosageUnit.present) {
      map['dosage_unit'] = Variable<String>(dosageUnit.value);
    }
    if (form.present) {
      map['form'] = Variable<String>(form.value);
    }
    if (escalationWindowMinutes.present) {
      map['escalation_window_minutes'] = Variable<int>(
        escalationWindowMinutes.value,
      );
    }
    if (followUpOffsetsMinutes.present) {
      map['follow_up_offsets_minutes'] = Variable<String>(
        followUpOffsetsMinutes.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DosesCompanion(')
          ..write('id: $id, ')
          ..write('scheduleId: $scheduleId, ')
          ..write('medicineId: $medicineId, ')
          ..write('scheduledLocal: $scheduledLocal, ')
          ..write('ianaTimezone: $ianaTimezone, ')
          ..write('scheduledUtc: $scheduledUtc, ')
          ..write('takenAt: $takenAt, ')
          ..write('skippedAt: $skippedAt, ')
          ..write('snoozedUntil: $snoozedUntil, ')
          ..write('snoozeCount: $snoozeCount, ')
          ..write('medicineName: $medicineName, ')
          ..write('dosageAmount: $dosageAmount, ')
          ..write('dosageUnit: $dosageUnit, ')
          ..write('form: $form, ')
          ..write('escalationWindowMinutes: $escalationWindowMinutes, ')
          ..write('followUpOffsetsMinutes: $followUpOffsetsMinutes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $MedicinesTable medicines = $MedicinesTable(this);
  late final $SchedulesTable schedules = $SchedulesTable(this);
  late final $DosesTable doses = $DosesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    appSettings,
    medicines,
    schedules,
    doses,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'medicines',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('schedules', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'schedules',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('doses', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'medicines',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('doses', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<int> id,
      Value<bool> onboardingCompleted,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<int> id,
      Value<bool> onboardingCompleted,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
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

  ColumnFilters<bool> get onboardingCompleted => $composableBuilder(
    column: $table.onboardingCompleted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
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

  ColumnOrderings<bool> get onboardingCompleted => $composableBuilder(
    column: $table.onboardingCompleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get onboardingCompleted => $composableBuilder(
    column: $table.onboardingCompleted,
    builder: (column) => column,
  );
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> onboardingCompleted = const Value.absent(),
              }) => AppSettingsCompanion(
                id: id,
                onboardingCompleted: onboardingCompleted,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> onboardingCompleted = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                id: id,
                onboardingCompleted: onboardingCompleted,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppSettingsTable, AppSetting>(table),
                  BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>(
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

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;
typedef $$MedicinesTableCreateCompanionBuilder =
    MedicinesCompanion Function({
      required String id,
      required String name,
      Value<String?> condition,
      required int glyphIndex,
      required String form,
      required double dosageAmount,
      required String dosageUnit,
      Value<String?> instructions,
      required String startDate,
      Value<String?> endDate,
      Value<bool> active,
      Value<int> rowid,
    });
typedef $$MedicinesTableUpdateCompanionBuilder =
    MedicinesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> condition,
      Value<int> glyphIndex,
      Value<String> form,
      Value<double> dosageAmount,
      Value<String> dosageUnit,
      Value<String?> instructions,
      Value<String> startDate,
      Value<String?> endDate,
      Value<bool> active,
      Value<int> rowid,
    });

final class $$MedicinesTableReferences
    extends BaseReferences<_$AppDatabase, $MedicinesTable, MedicineRow> {
  $$MedicinesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SchedulesTable, List<ScheduleRow>>
  _schedulesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.schedules,
    aliasName: 'medicines__id__schedules__medicine_id',
  );

  $$SchedulesTableProcessedTableManager get schedulesRefs {
    final manager = $$SchedulesTableTableManager(
      $_db,
      $_db.schedules,
    ).filter((f) => f.medicineId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_schedulesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DosesTable, List<DoseRow>> _dosesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.doses,
    aliasName: 'medicines__id__doses__medicine_id',
  );

  $$DosesTableProcessedTableManager get dosesRefs {
    final manager = $$DosesTableTableManager(
      $_db,
      $_db.doses,
    ).filter((f) => f.medicineId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_dosesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MedicinesTableFilterComposer
    extends Composer<_$AppDatabase, $MedicinesTable> {
  $$MedicinesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get condition => $composableBuilder(
    column: $table.condition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get glyphIndex => $composableBuilder(
    column: $table.glyphIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get form => $composableBuilder(
    column: $table.form,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get dosageAmount => $composableBuilder(
    column: $table.dosageAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dosageUnit => $composableBuilder(
    column: $table.dosageUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get instructions => $composableBuilder(
    column: $table.instructions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> schedulesRefs(
    Expression<bool> Function($$SchedulesTableFilterComposer f) f,
  ) {
    final $$SchedulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.schedules,
      getReferencedColumn: (t) => t.medicineId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SchedulesTableFilterComposer(
            $db: $db,
            $table: $db.schedules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> dosesRefs(
    Expression<bool> Function($$DosesTableFilterComposer f) f,
  ) {
    final $$DosesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.doses,
      getReferencedColumn: (t) => t.medicineId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DosesTableFilterComposer(
            $db: $db,
            $table: $db.doses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MedicinesTableOrderingComposer
    extends Composer<_$AppDatabase, $MedicinesTable> {
  $$MedicinesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get condition => $composableBuilder(
    column: $table.condition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get glyphIndex => $composableBuilder(
    column: $table.glyphIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get form => $composableBuilder(
    column: $table.form,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get dosageAmount => $composableBuilder(
    column: $table.dosageAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dosageUnit => $composableBuilder(
    column: $table.dosageUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get instructions => $composableBuilder(
    column: $table.instructions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MedicinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MedicinesTable> {
  $$MedicinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get condition =>
      $composableBuilder(column: $table.condition, builder: (column) => column);

  GeneratedColumn<int> get glyphIndex => $composableBuilder(
    column: $table.glyphIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get form =>
      $composableBuilder(column: $table.form, builder: (column) => column);

  GeneratedColumn<double> get dosageAmount => $composableBuilder(
    column: $table.dosageAmount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dosageUnit => $composableBuilder(
    column: $table.dosageUnit,
    builder: (column) => column,
  );

  GeneratedColumn<String> get instructions => $composableBuilder(
    column: $table.instructions,
    builder: (column) => column,
  );

  GeneratedColumn<String> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<String> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  Expression<T> schedulesRefs<T extends Object>(
    Expression<T> Function($$SchedulesTableAnnotationComposer a) f,
  ) {
    final $$SchedulesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.schedules,
      getReferencedColumn: (t) => t.medicineId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SchedulesTableAnnotationComposer(
            $db: $db,
            $table: $db.schedules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> dosesRefs<T extends Object>(
    Expression<T> Function($$DosesTableAnnotationComposer a) f,
  ) {
    final $$DosesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.doses,
      getReferencedColumn: (t) => t.medicineId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DosesTableAnnotationComposer(
            $db: $db,
            $table: $db.doses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MedicinesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MedicinesTable,
          MedicineRow,
          $$MedicinesTableFilterComposer,
          $$MedicinesTableOrderingComposer,
          $$MedicinesTableAnnotationComposer,
          $$MedicinesTableCreateCompanionBuilder,
          $$MedicinesTableUpdateCompanionBuilder,
          (MedicineRow, $$MedicinesTableReferences),
          MedicineRow,
          PrefetchHooks Function({bool schedulesRefs, bool dosesRefs})
        > {
  $$MedicinesTableTableManager(_$AppDatabase db, $MedicinesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MedicinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MedicinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MedicinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> condition = const Value.absent(),
                Value<int> glyphIndex = const Value.absent(),
                Value<String> form = const Value.absent(),
                Value<double> dosageAmount = const Value.absent(),
                Value<String> dosageUnit = const Value.absent(),
                Value<String?> instructions = const Value.absent(),
                Value<String> startDate = const Value.absent(),
                Value<String?> endDate = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MedicinesCompanion(
                id: id,
                name: name,
                condition: condition,
                glyphIndex: glyphIndex,
                form: form,
                dosageAmount: dosageAmount,
                dosageUnit: dosageUnit,
                instructions: instructions,
                startDate: startDate,
                endDate: endDate,
                active: active,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> condition = const Value.absent(),
                required int glyphIndex,
                required String form,
                required double dosageAmount,
                required String dosageUnit,
                Value<String?> instructions = const Value.absent(),
                required String startDate,
                Value<String?> endDate = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MedicinesCompanion.insert(
                id: id,
                name: name,
                condition: condition,
                glyphIndex: glyphIndex,
                form: form,
                dosageAmount: dosageAmount,
                dosageUnit: dosageUnit,
                instructions: instructions,
                startDate: startDate,
                endDate: endDate,
                active: active,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MedicinesTable, MedicineRow>(table),
                  $$MedicinesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({schedulesRefs = false, dosesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (schedulesRefs) db.schedules,
                if (dosesRefs) db.doses,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (schedulesRefs)
                    await $_getPrefetchedData<
                      MedicineRow,
                      $MedicinesTable,
                      ScheduleRow
                    >(
                      currentTable: table,
                      referencedTable: $$MedicinesTableReferences
                          ._schedulesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$MedicinesTableReferences(
                            db,
                            table,
                            p0,
                          ).schedulesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.medicineId == item.id),
                      typedResults: items,
                    ),
                  if (dosesRefs)
                    await $_getPrefetchedData<
                      MedicineRow,
                      $MedicinesTable,
                      DoseRow
                    >(
                      currentTable: table,
                      referencedTable: $$MedicinesTableReferences
                          ._dosesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$MedicinesTableReferences(db, table, p0).dosesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.medicineId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$MedicinesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MedicinesTable,
      MedicineRow,
      $$MedicinesTableFilterComposer,
      $$MedicinesTableOrderingComposer,
      $$MedicinesTableAnnotationComposer,
      $$MedicinesTableCreateCompanionBuilder,
      $$MedicinesTableUpdateCompanionBuilder,
      (MedicineRow, $$MedicinesTableReferences),
      MedicineRow,
      PrefetchHooks Function({bool schedulesRefs, bool dosesRefs})
    >;
typedef $$SchedulesTableCreateCompanionBuilder =
    SchedulesCompanion Function({
      required String id,
      required String medicineId,
      required String timeOfDay,
      required String ianaTimezone,
      required String frequency,
      Value<String?> daysOfWeek,
      Value<int?> intervalDays,
      required double dosageAmount,
      Value<String?> reminderOverride,
      Value<int> rowid,
    });
typedef $$SchedulesTableUpdateCompanionBuilder =
    SchedulesCompanion Function({
      Value<String> id,
      Value<String> medicineId,
      Value<String> timeOfDay,
      Value<String> ianaTimezone,
      Value<String> frequency,
      Value<String?> daysOfWeek,
      Value<int?> intervalDays,
      Value<double> dosageAmount,
      Value<String?> reminderOverride,
      Value<int> rowid,
    });

final class $$SchedulesTableReferences
    extends BaseReferences<_$AppDatabase, $SchedulesTable, ScheduleRow> {
  $$SchedulesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MedicinesTable _medicineIdTable(_$AppDatabase db) =>
      db.medicines.createAlias('schedules__medicine_id__medicines__id');

  $$MedicinesTableProcessedTableManager get medicineId {
    final $_column = $_itemColumn<String>('medicine_id')!;

    final manager = $$MedicinesTableTableManager(
      $_db,
      $_db.medicines,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_medicineIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$DosesTable, List<DoseRow>> _dosesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.doses,
    aliasName: 'schedules__id__doses__schedule_id',
  );

  $$DosesTableProcessedTableManager get dosesRefs {
    final manager = $$DosesTableTableManager(
      $_db,
      $_db.doses,
    ).filter((f) => f.scheduleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_dosesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SchedulesTableFilterComposer
    extends Composer<_$AppDatabase, $SchedulesTable> {
  $$SchedulesTableFilterComposer({
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

  ColumnFilters<String> get timeOfDay => $composableBuilder(
    column: $table.timeOfDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ianaTimezone => $composableBuilder(
    column: $table.ianaTimezone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get daysOfWeek => $composableBuilder(
    column: $table.daysOfWeek,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get dosageAmount => $composableBuilder(
    column: $table.dosageAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reminderOverride => $composableBuilder(
    column: $table.reminderOverride,
    builder: (column) => ColumnFilters(column),
  );

  $$MedicinesTableFilterComposer get medicineId {
    final $$MedicinesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.medicineId,
      referencedTable: $db.medicines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MedicinesTableFilterComposer(
            $db: $db,
            $table: $db.medicines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> dosesRefs(
    Expression<bool> Function($$DosesTableFilterComposer f) f,
  ) {
    final $$DosesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.doses,
      getReferencedColumn: (t) => t.scheduleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DosesTableFilterComposer(
            $db: $db,
            $table: $db.doses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SchedulesTableOrderingComposer
    extends Composer<_$AppDatabase, $SchedulesTable> {
  $$SchedulesTableOrderingComposer({
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

  ColumnOrderings<String> get timeOfDay => $composableBuilder(
    column: $table.timeOfDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ianaTimezone => $composableBuilder(
    column: $table.ianaTimezone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get daysOfWeek => $composableBuilder(
    column: $table.daysOfWeek,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get dosageAmount => $composableBuilder(
    column: $table.dosageAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reminderOverride => $composableBuilder(
    column: $table.reminderOverride,
    builder: (column) => ColumnOrderings(column),
  );

  $$MedicinesTableOrderingComposer get medicineId {
    final $$MedicinesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.medicineId,
      referencedTable: $db.medicines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MedicinesTableOrderingComposer(
            $db: $db,
            $table: $db.medicines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SchedulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SchedulesTable> {
  $$SchedulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get timeOfDay =>
      $composableBuilder(column: $table.timeOfDay, builder: (column) => column);

  GeneratedColumn<String> get ianaTimezone => $composableBuilder(
    column: $table.ianaTimezone,
    builder: (column) => column,
  );

  GeneratedColumn<String> get frequency =>
      $composableBuilder(column: $table.frequency, builder: (column) => column);

  GeneratedColumn<String> get daysOfWeek => $composableBuilder(
    column: $table.daysOfWeek,
    builder: (column) => column,
  );

  GeneratedColumn<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => column,
  );

  GeneratedColumn<double> get dosageAmount => $composableBuilder(
    column: $table.dosageAmount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reminderOverride => $composableBuilder(
    column: $table.reminderOverride,
    builder: (column) => column,
  );

  $$MedicinesTableAnnotationComposer get medicineId {
    final $$MedicinesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.medicineId,
      referencedTable: $db.medicines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MedicinesTableAnnotationComposer(
            $db: $db,
            $table: $db.medicines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> dosesRefs<T extends Object>(
    Expression<T> Function($$DosesTableAnnotationComposer a) f,
  ) {
    final $$DosesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.doses,
      getReferencedColumn: (t) => t.scheduleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DosesTableAnnotationComposer(
            $db: $db,
            $table: $db.doses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SchedulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SchedulesTable,
          ScheduleRow,
          $$SchedulesTableFilterComposer,
          $$SchedulesTableOrderingComposer,
          $$SchedulesTableAnnotationComposer,
          $$SchedulesTableCreateCompanionBuilder,
          $$SchedulesTableUpdateCompanionBuilder,
          (ScheduleRow, $$SchedulesTableReferences),
          ScheduleRow,
          PrefetchHooks Function({bool medicineId, bool dosesRefs})
        > {
  $$SchedulesTableTableManager(_$AppDatabase db, $SchedulesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SchedulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SchedulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SchedulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> medicineId = const Value.absent(),
                Value<String> timeOfDay = const Value.absent(),
                Value<String> ianaTimezone = const Value.absent(),
                Value<String> frequency = const Value.absent(),
                Value<String?> daysOfWeek = const Value.absent(),
                Value<int?> intervalDays = const Value.absent(),
                Value<double> dosageAmount = const Value.absent(),
                Value<String?> reminderOverride = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SchedulesCompanion(
                id: id,
                medicineId: medicineId,
                timeOfDay: timeOfDay,
                ianaTimezone: ianaTimezone,
                frequency: frequency,
                daysOfWeek: daysOfWeek,
                intervalDays: intervalDays,
                dosageAmount: dosageAmount,
                reminderOverride: reminderOverride,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String medicineId,
                required String timeOfDay,
                required String ianaTimezone,
                required String frequency,
                Value<String?> daysOfWeek = const Value.absent(),
                Value<int?> intervalDays = const Value.absent(),
                required double dosageAmount,
                Value<String?> reminderOverride = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SchedulesCompanion.insert(
                id: id,
                medicineId: medicineId,
                timeOfDay: timeOfDay,
                ianaTimezone: ianaTimezone,
                frequency: frequency,
                daysOfWeek: daysOfWeek,
                intervalDays: intervalDays,
                dosageAmount: dosageAmount,
                reminderOverride: reminderOverride,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SchedulesTable, ScheduleRow>(table),
                  $$SchedulesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({medicineId = false, dosesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (dosesRefs) db.doses],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (medicineId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.medicineId,
                                referencedTable: $$SchedulesTableReferences
                                    ._medicineIdTable(db),
                                referencedColumn: $$SchedulesTableReferences
                                    ._medicineIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (dosesRefs)
                    await $_getPrefetchedData<
                      ScheduleRow,
                      $SchedulesTable,
                      DoseRow
                    >(
                      currentTable: table,
                      referencedTable: $$SchedulesTableReferences
                          ._dosesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$SchedulesTableReferences(db, table, p0).dosesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.scheduleId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SchedulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SchedulesTable,
      ScheduleRow,
      $$SchedulesTableFilterComposer,
      $$SchedulesTableOrderingComposer,
      $$SchedulesTableAnnotationComposer,
      $$SchedulesTableCreateCompanionBuilder,
      $$SchedulesTableUpdateCompanionBuilder,
      (ScheduleRow, $$SchedulesTableReferences),
      ScheduleRow,
      PrefetchHooks Function({bool medicineId, bool dosesRefs})
    >;
typedef $$DosesTableCreateCompanionBuilder =
    DosesCompanion Function({
      required String id,
      required String scheduleId,
      required String medicineId,
      required String scheduledLocal,
      required String ianaTimezone,
      required String scheduledUtc,
      Value<String?> takenAt,
      Value<String?> skippedAt,
      Value<String?> snoozedUntil,
      Value<int> snoozeCount,
      required String medicineName,
      required double dosageAmount,
      required String dosageUnit,
      required String form,
      required int escalationWindowMinutes,
      required String followUpOffsetsMinutes,
      Value<int> rowid,
    });
typedef $$DosesTableUpdateCompanionBuilder =
    DosesCompanion Function({
      Value<String> id,
      Value<String> scheduleId,
      Value<String> medicineId,
      Value<String> scheduledLocal,
      Value<String> ianaTimezone,
      Value<String> scheduledUtc,
      Value<String?> takenAt,
      Value<String?> skippedAt,
      Value<String?> snoozedUntil,
      Value<int> snoozeCount,
      Value<String> medicineName,
      Value<double> dosageAmount,
      Value<String> dosageUnit,
      Value<String> form,
      Value<int> escalationWindowMinutes,
      Value<String> followUpOffsetsMinutes,
      Value<int> rowid,
    });

final class $$DosesTableReferences
    extends BaseReferences<_$AppDatabase, $DosesTable, DoseRow> {
  $$DosesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SchedulesTable _scheduleIdTable(_$AppDatabase db) =>
      db.schedules.createAlias('doses__schedule_id__schedules__id');

  $$SchedulesTableProcessedTableManager get scheduleId {
    final $_column = $_itemColumn<String>('schedule_id')!;

    final manager = $$SchedulesTableTableManager(
      $_db,
      $_db.schedules,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_scheduleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $MedicinesTable _medicineIdTable(_$AppDatabase db) =>
      db.medicines.createAlias('doses__medicine_id__medicines__id');

  $$MedicinesTableProcessedTableManager get medicineId {
    final $_column = $_itemColumn<String>('medicine_id')!;

    final manager = $$MedicinesTableTableManager(
      $_db,
      $_db.medicines,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_medicineIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DosesTableFilterComposer extends Composer<_$AppDatabase, $DosesTable> {
  $$DosesTableFilterComposer({
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

  ColumnFilters<String> get scheduledLocal => $composableBuilder(
    column: $table.scheduledLocal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ianaTimezone => $composableBuilder(
    column: $table.ianaTimezone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scheduledUtc => $composableBuilder(
    column: $table.scheduledUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get takenAt => $composableBuilder(
    column: $table.takenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get skippedAt => $composableBuilder(
    column: $table.skippedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get snoozeCount => $composableBuilder(
    column: $table.snoozeCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get medicineName => $composableBuilder(
    column: $table.medicineName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get dosageAmount => $composableBuilder(
    column: $table.dosageAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dosageUnit => $composableBuilder(
    column: $table.dosageUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get form => $composableBuilder(
    column: $table.form,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get escalationWindowMinutes => $composableBuilder(
    column: $table.escalationWindowMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get followUpOffsetsMinutes => $composableBuilder(
    column: $table.followUpOffsetsMinutes,
    builder: (column) => ColumnFilters(column),
  );

  $$SchedulesTableFilterComposer get scheduleId {
    final $$SchedulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scheduleId,
      referencedTable: $db.schedules,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SchedulesTableFilterComposer(
            $db: $db,
            $table: $db.schedules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MedicinesTableFilterComposer get medicineId {
    final $$MedicinesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.medicineId,
      referencedTable: $db.medicines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MedicinesTableFilterComposer(
            $db: $db,
            $table: $db.medicines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DosesTableOrderingComposer
    extends Composer<_$AppDatabase, $DosesTable> {
  $$DosesTableOrderingComposer({
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

  ColumnOrderings<String> get scheduledLocal => $composableBuilder(
    column: $table.scheduledLocal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ianaTimezone => $composableBuilder(
    column: $table.ianaTimezone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scheduledUtc => $composableBuilder(
    column: $table.scheduledUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get takenAt => $composableBuilder(
    column: $table.takenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get skippedAt => $composableBuilder(
    column: $table.skippedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get snoozeCount => $composableBuilder(
    column: $table.snoozeCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get medicineName => $composableBuilder(
    column: $table.medicineName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get dosageAmount => $composableBuilder(
    column: $table.dosageAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dosageUnit => $composableBuilder(
    column: $table.dosageUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get form => $composableBuilder(
    column: $table.form,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get escalationWindowMinutes => $composableBuilder(
    column: $table.escalationWindowMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get followUpOffsetsMinutes => $composableBuilder(
    column: $table.followUpOffsetsMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  $$SchedulesTableOrderingComposer get scheduleId {
    final $$SchedulesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scheduleId,
      referencedTable: $db.schedules,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SchedulesTableOrderingComposer(
            $db: $db,
            $table: $db.schedules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MedicinesTableOrderingComposer get medicineId {
    final $$MedicinesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.medicineId,
      referencedTable: $db.medicines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MedicinesTableOrderingComposer(
            $db: $db,
            $table: $db.medicines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DosesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DosesTable> {
  $$DosesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get scheduledLocal => $composableBuilder(
    column: $table.scheduledLocal,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ianaTimezone => $composableBuilder(
    column: $table.ianaTimezone,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scheduledUtc => $composableBuilder(
    column: $table.scheduledUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get takenAt =>
      $composableBuilder(column: $table.takenAt, builder: (column) => column);

  GeneratedColumn<String> get skippedAt =>
      $composableBuilder(column: $table.skippedAt, builder: (column) => column);

  GeneratedColumn<String> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => column,
  );

  GeneratedColumn<int> get snoozeCount => $composableBuilder(
    column: $table.snoozeCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get medicineName => $composableBuilder(
    column: $table.medicineName,
    builder: (column) => column,
  );

  GeneratedColumn<double> get dosageAmount => $composableBuilder(
    column: $table.dosageAmount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dosageUnit => $composableBuilder(
    column: $table.dosageUnit,
    builder: (column) => column,
  );

  GeneratedColumn<String> get form =>
      $composableBuilder(column: $table.form, builder: (column) => column);

  GeneratedColumn<int> get escalationWindowMinutes => $composableBuilder(
    column: $table.escalationWindowMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get followUpOffsetsMinutes => $composableBuilder(
    column: $table.followUpOffsetsMinutes,
    builder: (column) => column,
  );

  $$SchedulesTableAnnotationComposer get scheduleId {
    final $$SchedulesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scheduleId,
      referencedTable: $db.schedules,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SchedulesTableAnnotationComposer(
            $db: $db,
            $table: $db.schedules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MedicinesTableAnnotationComposer get medicineId {
    final $$MedicinesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.medicineId,
      referencedTable: $db.medicines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MedicinesTableAnnotationComposer(
            $db: $db,
            $table: $db.medicines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DosesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DosesTable,
          DoseRow,
          $$DosesTableFilterComposer,
          $$DosesTableOrderingComposer,
          $$DosesTableAnnotationComposer,
          $$DosesTableCreateCompanionBuilder,
          $$DosesTableUpdateCompanionBuilder,
          (DoseRow, $$DosesTableReferences),
          DoseRow,
          PrefetchHooks Function({bool scheduleId, bool medicineId})
        > {
  $$DosesTableTableManager(_$AppDatabase db, $DosesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DosesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DosesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DosesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> scheduleId = const Value.absent(),
                Value<String> medicineId = const Value.absent(),
                Value<String> scheduledLocal = const Value.absent(),
                Value<String> ianaTimezone = const Value.absent(),
                Value<String> scheduledUtc = const Value.absent(),
                Value<String?> takenAt = const Value.absent(),
                Value<String?> skippedAt = const Value.absent(),
                Value<String?> snoozedUntil = const Value.absent(),
                Value<int> snoozeCount = const Value.absent(),
                Value<String> medicineName = const Value.absent(),
                Value<double> dosageAmount = const Value.absent(),
                Value<String> dosageUnit = const Value.absent(),
                Value<String> form = const Value.absent(),
                Value<int> escalationWindowMinutes = const Value.absent(),
                Value<String> followUpOffsetsMinutes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DosesCompanion(
                id: id,
                scheduleId: scheduleId,
                medicineId: medicineId,
                scheduledLocal: scheduledLocal,
                ianaTimezone: ianaTimezone,
                scheduledUtc: scheduledUtc,
                takenAt: takenAt,
                skippedAt: skippedAt,
                snoozedUntil: snoozedUntil,
                snoozeCount: snoozeCount,
                medicineName: medicineName,
                dosageAmount: dosageAmount,
                dosageUnit: dosageUnit,
                form: form,
                escalationWindowMinutes: escalationWindowMinutes,
                followUpOffsetsMinutes: followUpOffsetsMinutes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String scheduleId,
                required String medicineId,
                required String scheduledLocal,
                required String ianaTimezone,
                required String scheduledUtc,
                Value<String?> takenAt = const Value.absent(),
                Value<String?> skippedAt = const Value.absent(),
                Value<String?> snoozedUntil = const Value.absent(),
                Value<int> snoozeCount = const Value.absent(),
                required String medicineName,
                required double dosageAmount,
                required String dosageUnit,
                required String form,
                required int escalationWindowMinutes,
                required String followUpOffsetsMinutes,
                Value<int> rowid = const Value.absent(),
              }) => DosesCompanion.insert(
                id: id,
                scheduleId: scheduleId,
                medicineId: medicineId,
                scheduledLocal: scheduledLocal,
                ianaTimezone: ianaTimezone,
                scheduledUtc: scheduledUtc,
                takenAt: takenAt,
                skippedAt: skippedAt,
                snoozedUntil: snoozedUntil,
                snoozeCount: snoozeCount,
                medicineName: medicineName,
                dosageAmount: dosageAmount,
                dosageUnit: dosageUnit,
                form: form,
                escalationWindowMinutes: escalationWindowMinutes,
                followUpOffsetsMinutes: followUpOffsetsMinutes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DosesTable, DoseRow>(table),
                  $$DosesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({scheduleId = false, medicineId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (scheduleId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.scheduleId,
                                referencedTable: $$DosesTableReferences
                                    ._scheduleIdTable(db),
                                referencedColumn: $$DosesTableReferences
                                    ._scheduleIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (medicineId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.medicineId,
                                referencedTable: $$DosesTableReferences
                                    ._medicineIdTable(db),
                                referencedColumn: $$DosesTableReferences
                                    ._medicineIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DosesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DosesTable,
      DoseRow,
      $$DosesTableFilterComposer,
      $$DosesTableOrderingComposer,
      $$DosesTableAnnotationComposer,
      $$DosesTableCreateCompanionBuilder,
      $$DosesTableUpdateCompanionBuilder,
      (DoseRow, $$DosesTableReferences),
      DoseRow,
      PrefetchHooks Function({bool scheduleId, bool medicineId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$MedicinesTableTableManager get medicines =>
      $$MedicinesTableTableManager(_db, _db.medicines);
  $$SchedulesTableTableManager get schedules =>
      $$SchedulesTableTableManager(_db, _db.schedules);
  $$DosesTableTableManager get doses =>
      $$DosesTableTableManager(_db, _db.doses);
}
