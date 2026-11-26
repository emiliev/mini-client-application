# T-0041-AC7: comics_details codegen vs build_runner

Overlay inputs: `//feature/comics/comics_details:_stage` (plus the init file for injectable).

```
== 1. Bazel codegen for //feature/comics/comics_details
INFO: Build completed successfully, 33 total actions
== 2. Overlay scratch tree .dart_tool/mc_overlay/comics_details
   17 files from //feature/comics/comics_details:_stage
== 3. Resolve (hosted versions must equal the committed overlay lock)
== 4. build_runner
  Built with build_runner/aot in 14s; wrote 9 outputs.
   dart analyze: no unresolved imports
== 5. Compare with bazel-bin (declared outputs only)
EQUAL   feature/comics/comics_details/lib/src/domain/api/comics_details_api.g.dart  sha256 07c324a592cbbbf4
EQUAL   feature/comics/comics_details/lib/src/domain/model/comic.freezed.dart  sha256 e3de81aba3a5a531
DIFFER  feature/comics/comics_details/lib/src/domain/model/comic_dto.freezed.dart
--- ./lib/src/domain/model/comic_dto.freezed.dart	2026-11-26 19:58:52
+++ /private/tmp/mc-ob-T-0041-engineer/execroot/_main/bazel-out/darwin_arm64-fastbuild/bin/feature/comics/comics_details/lib/src/domain/model/comic_dto.freezed.dart	2026-11-26 19:58:32
@@ -12,7 +12,6 @@
 // GENERATED CODE - DO NOT MODIFY BY HAND
 // dart format off
 T _$identity<T>(T value) => value;
-
 /// @nodoc
 mixin _$ComicDto {
 
@@ -24,8 +23,6 @@
 @pragma('vm:prefer-inline')
 $ComicDtoCopyWith<ComicDto> get copyWith => _$ComicDtoCopyWithImpl<ComicDto>(this as ComicDto, _$identity);
 
-  /// Serializes this ComicDto to a JSON map.
-  Map<String, dynamic> toJson();
 
 
 @override
@@ -34,7 +31,7 @@
   return identical(this, other) || (other.runtimeType == runtimeType&&other is ComicDto&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.issueNumber, _this.issueNumber) || other.issueNumber == _this.issueNumber)&&(identical(other.seriesId, _this.seriesId) || other.seriesId == _this.seriesId)&&(identical(other.releaseDate, _this.releaseDate) || other.releaseDate == _this.releaseDate)&&(identical(other.cover, _this.cover) || other.cover == _this.cover)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.series, _this.series) || other.series == _this.series)&&const DeepCollectionEquality().equals(other.creators, _this.creators)&&const DeepCollectionEquality().equals(other.characterIds, _this.characterIds)&&(identical(other.price, _this.price) || other.price == _this.price)&&(identical(other.pageCount, _this.pageCount) || other.pageCount == _this.pageCount)&&const DeepCollectionEquality().equals(other.variants, _this.variants));
 }
 
-@JsonKey(includeFromJson: false, includeToJson: false)
+
 @override
 int get hashCode {
   final _this = this as ComicDto;
@@ -256,7 +253,7 @@
 @JsonSerializable(explicitToJson: true)
 class _ComicDto implements ComicDto {
   const _ComicDto({required this.id, required this.title, required this.issueNumber, required this.seriesId, required this.releaseDate, required this.cover, required this.description, required this.series, required  List<CreditDto> creators, required  List<int> characterIds, required this.price, required this.pageCount, required  List<VariantDto> variants}): _creators = creators,_characterIds = characterIds,_variants = variants;
-  factory _ComicDto.fromJson(Map<String, dynamic> json) => _$ComicDtoFromJson(json);
+  
 
 @override final  int id;
 @override final  String title;
@@ -297,17 +294,14 @@
 @pragma('vm:prefer-inline')
 _$ComicDtoCopyWith<_ComicDto> get copyWith => __$ComicDtoCopyWithImpl<_ComicDto>(this, _$identity);
 
-@override
-Map<String, dynamic> toJson() {
-  return _$ComicDtoToJson(this, );
-}
 
+
 @override
 bool operator ==(Object other) {
     return identical(this, other) || (other.runtimeType == runtimeType&&other is _ComicDto&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.issueNumber, issueNumber) || other.issueNumber == issueNumber)&&(identical(other.seriesId, seriesId) || other.seriesId == seriesId)&&(identical(other.releaseDate, releaseDate) || other.releaseDate == releaseDate)&&(identical(other.cover, cover) || other.cover == cover)&&(identical(other.description, description) || other.description == description)&&(identical(other.series, series) || other.series == series)&&const DeepCollectionEquality().equals(other.creators, _creators)&&const DeepCollectionEquality().equals(other.characterIds, _characterIds)&&(identical(other.price, price) || other.price == price)&&(identical(other.pageCount, pageCount) || other.pageCount == pageCount)&&const DeepCollectionEquality().equals(other.variants, _variants));
 }
 
-@JsonKey(includeFromJson: false, includeToJson: false)
+
 @override
 int get hashCode {
     return Object.hash(runtimeType,id,title,issueNumber,seriesId,releaseDate,cover,description,series,const DeepCollectionEquality().hash(_creators),const DeepCollectionEquality().hash(_characterIds),price,pageCount,const DeepCollectionEquality().hash(_variants));
EQUAL   feature/comics/comics_details/lib/src/domain/model/comic_dto.g.dart  sha256 2aa8a7ab2b1abfc4
EQUAL   feature/comics/comics_details/lib/src/flow/comics_details_flow_state.freezed.dart  sha256 a0c1d46a82fe4051
EQUAL   feature/comics/comics_details/lib/src/presentation/bloc/comic_details_bloc.freezed.dart  sha256 256d1d90025d9b07
EQUAL   feature/comics/comics_details/lib/src/presentation/bloc/comic_favourite_bloc.freezed.dart  sha256 f93bfc2d9d5ba2b7
== 1. Bazel injectable codegen for //feature/comics/comics_details
INFO: Build completed successfully, 1 total action
== 2. Overlay scratch tree .dart_tool/mc_overlay/comics_details_injectable
   18 files from //feature/comics/comics_details:_stage and the init file(s)
== 3. Resolve (hosted versions must equal the committed overlay lock)
ADDED bloc characters clock flutter flutter_bloc freezed_annotation intl material_color_utilities nested provider retrofit sky_engine vector_math
   analyzer "14.1.0", lean_builder "1.2.2"
== 4. build_runner
  Built with build_runner/aot in 12s; wrote 5 outputs.
== 5. Compare with bazel-bin
EQUAL   feature/comics/comics_details/lib/src/di/di_initializer.config.dart  sha256 0bf8dd209ab5fafa
EQUAL   feature/comics/comics_details/lib/src/domain/api/comics_details_api.injectable.json (shard)  sha256 1227d3eae0815f1e
EQUAL   feature/comics/comics_details/lib/src/domain/repository/comics_details_repository.injectable.json (shard)  sha256 1b23b3f9c8b9eb07
EQUAL   feature/comics/comics_details/lib/src/presentation/bloc/comic_details_bloc.injectable.json (shard)  sha256 440ca26df7e877b4
EQUAL   feature/comics/comics_details/lib/src/presentation/bloc/comic_favourite_bloc.injectable.json (shard)  sha256 f802d518ea2ae176
```

| Check | Result |
|---|---|
| spike_reference.sh (freezed, json, retrofit) | exit 1 |
| injectable_reference.sh (config + shards) | exit 0 |
| expected files EQUAL | 11 of 12 |
| expected but not EQUAL | feature/comics/comics_details/lib/src/domain/model/comic_dto.freezed.dart |
| EQUAL but not on the list | none |

**FAIL T-0041-AC7-byte-identity**
