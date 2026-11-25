# T-0032-AC6: characters_list codegen vs build_runner

Overlay inputs: `//feature/characters/characters_list:_stage` (plus the init file for injectable).

```
== 1. Bazel codegen for //feature/characters/characters_list
INFO: Build completed successfully, 23 total actions
== 2. Overlay scratch tree .dart_tool/mc_overlay/characters_list
   14 files from //feature/characters/characters_list:_stage
== 3. Resolve (hosted versions must equal the committed overlay lock)
== 4. build_runner
  Built with build_runner/aot in 13s; wrote 8 outputs.
   dart analyze: no unresolved imports
== 5. Compare with bazel-bin (declared outputs only)
EQUAL   feature/characters/characters_list/lib/src/domain/api/characters_list_api.g.dart  sha256 36401c9e5f6ced2a
EQUAL   feature/characters/characters_list/lib/src/domain/model/character.freezed.dart  sha256 df12820ec377eab6
DIFFER  feature/characters/characters_list/lib/src/domain/model/character_dto.freezed.dart
--- ./lib/src/domain/model/character_dto.freezed.dart	2026-11-25 06:35:05
+++ /private/tmp/mc-ob-T-0032-engineer/execroot/_main/bazel-out/darwin_arm64-fastbuild/bin/feature/characters/characters_list/lib/src/domain/model/character_dto.freezed.dart	2026-11-25 06:34:47
@@ -12,7 +12,6 @@
 // GENERATED CODE - DO NOT MODIFY BY HAND
 // dart format off
 T _$identity<T>(T value) => value;
-
 /// @nodoc
 mixin _$CharacterDto {
 
@@ -23,8 +22,6 @@
 @pragma('vm:prefer-inline')
 $CharacterDtoCopyWith<CharacterDto> get copyWith => _$CharacterDtoCopyWithImpl<CharacterDto>(this as CharacterDto, _$identity);
 
-  /// Serializes this CharacterDto to a JSON map.
-  Map<String, dynamic> toJson();
 
 
 @override
@@ -33,7 +30,7 @@
   return identical(this, other) || (other.runtimeType == runtimeType&&other is CharacterDto&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.modified, _this.modified) || other.modified == _this.modified)&&(identical(other.thumbnail, _this.thumbnail) || other.thumbnail == _this.thumbnail));
 }
 
-@JsonKey(includeFromJson: false, includeToJson: false)
+
 @override
 int get hashCode {
   final _this = this as CharacterDto;
@@ -229,7 +226,7 @@
 @JsonSerializable(explicitToJson: true)
 class _CharacterDto implements CharacterDto {
   const _CharacterDto({required this.id, required this.name, required this.description, required this.modified, required this.thumbnail});
-  factory _CharacterDto.fromJson(Map<String, dynamic> json) => _$CharacterDtoFromJson(json);
+  
 
 @override final  int id;
 @override final  String name;
@@ -243,17 +240,14 @@
 @pragma('vm:prefer-inline')
 _$CharacterDtoCopyWith<_CharacterDto> get copyWith => __$CharacterDtoCopyWithImpl<_CharacterDto>(this, _$identity);
 
-@override
-Map<String, dynamic> toJson() {
-  return _$CharacterDtoToJson(this, );
-}
 
+
 @override
 bool operator ==(Object other) {
     return identical(this, other) || (other.runtimeType == runtimeType&&other is _CharacterDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.modified, modified) || other.modified == modified)&&(identical(other.thumbnail, thumbnail) || other.thumbnail == thumbnail));
 }
 
-@JsonKey(includeFromJson: false, includeToJson: false)
+
 @override
 int get hashCode {
     return Object.hash(runtimeType,id,name,description,modified,thumbnail);
EQUAL   feature/characters/characters_list/lib/src/domain/model/character_dto.g.dart  sha256 5cfff5a2c7ab408c
EQUAL   feature/characters/characters_list/lib/src/flow/characters_list_flow_state.freezed.dart  sha256 cc2848b05137068c
EQUAL   feature/characters/characters_list/lib/src/presentation/bloc/characters_list_bloc.freezed.dart  sha256 3995d8bbc373b5fe
== 1. Bazel injectable codegen for //feature/characters/characters_list
INFO: Build completed successfully, 1 total action
== 2. Overlay scratch tree .dart_tool/mc_overlay/characters_list_injectable
   15 files from //feature/characters/characters_list:_stage and the init file(s)
== 3. Resolve (hosted versions must equal the committed overlay lock)
ADDED bloc characters clock flutter flutter_bloc freezed_annotation intl material_color_utilities nested provider retrofit sky_engine vector_math
   analyzer "14.1.0", lean_builder "1.2.2"
== 4. build_runner
  Built with build_runner/aot in 11s; wrote 5 outputs.
== 5. Compare with bazel-bin
EQUAL   feature/characters/characters_list/lib/src/di/di_initializer.config.dart  sha256 192685730c453c3f
EQUAL   feature/characters/characters_list/lib/src/domain/api/characters_list_api.injectable.json (shard)  sha256 1d367020be76e321
EQUAL   feature/characters/characters_list/lib/src/domain/repository/characters_list_repository.injectable.json (shard)  sha256 d450d781674b1df9
EQUAL   feature/characters/characters_list/lib/src/presentation/bloc/character_preview_bloc.injectable.json (shard)  sha256 0702fa85cc02ac19
EQUAL   feature/characters/characters_list/lib/src/presentation/bloc/characters_list_bloc.injectable.json (shard)  sha256 5a1e4bb9319fafe1
```

| Check | Result |
|---|---|
| spike_reference.sh (freezed, json, retrofit) | exit 1 |
| injectable_reference.sh (config + shards) | exit 0 |
| expected files EQUAL | 10 of 11 |
| expected but not EQUAL | feature/characters/characters_list/lib/src/domain/model/character_dto.freezed.dart |
| EQUAL but not on the list | none |

**FAIL T-0032-AC6-byte-identity**
