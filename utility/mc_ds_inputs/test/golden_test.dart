import 'package:flutter/material.dart';
import 'package:mc_ds_inputs/mc_ds_inputs.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

const _german =
    'Donaudampfschifffahrtsgesellschaftskapitänsmützenabzeichen-Beschreibung';

const _options = [
  McChipOption<String>(value: 'a', label: 'Helden'),
  McChipOption<String>(value: 'b', label: 'Bösewichte', icon: Icons.bolt),
  McChipOption<String>(value: 'c', label: 'Außerirdische'),
  McChipOption<String>(value: 'd', label: _german),
];

Widget _pad(List<Widget> children) => Padding(
  padding: const EdgeInsets.all(16),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final c in children) ...[c, const SizedBox(height: 12)],
    ],
  ),
);

McStepper _stepper(int value, {bool enabled = true}) => McStepper(
  value: value,
  onChanged: enabled ? (_) {} : null,
  label: 'Quantity',
  decreaseLabel: 'Decrease quantity',
  increaseLabel: 'Increase quantity',
  min: 0,
  max: 5,
);

TextEditingController _c([String text = '']) =>
    TextEditingController(text: text);

void main() {
  const ac = 'T-0044-AC1';

  mcGoldenMatrix(
    acId: ac,
    component: 'text_field_empty',
    height: 100,
    heightAtScale2: 130,
    builder: (_) => _pad([
      McTextField(controller: _c(), label: 'Name', hint: 'Peter Parker'),
    ]),
  );
  mcGoldenMatrix(
    acId: ac,
    component: 'text_field_filled',
    height: 120,
    heightAtScale2: 150,
    builder: (_) => _pad([
      McTextField(
        controller: _c('Peter Parker'),
        label: 'Name',
        helperText: 'As on the passport',
      ),
    ]),
  );
  mcGoldenMatrix(
    acId: ac,
    component: 'text_field_focused',
    height: 120,
    heightAtScale2: 150,
    builder: (_) => _pad([
      McTextField(
        controller: _c('Peter'),
        label: 'Name',
        helperText: 'As on the passport',
        autofocus: true,
      ),
    ]),
  );
  mcGoldenMatrix(
    acId: ac,
    component: 'text_field_error',
    height: 120,
    heightAtScale2: 190,
    builder: (_) => _pad([
      McTextField(
        controller: _c('peter@'),
        label: 'Email',
        helperText: 'We never share it',
        errorText: 'Enter a valid email address',
      ),
    ]),
  );
  mcGoldenMatrix(
    acId: ac,
    component: 'text_field_disabled',
    height: 140,
    heightAtScale2: 190,
    builder: (_) => _pad([
      McTextField(
        controller: _c('Locked'),
        label: 'Name',
        helperText: 'Cannot be changed',
        enabled: false,
      ),
    ]),
  );
  mcGoldenMatrix(
    acId: ac,
    component: 'text_field_affixes',
    height: 180,
    heightAtScale2: 230,
    builder: (_) => _pad([
      McTextField(
        controller: _c('secret'),
        label: 'Password',
        obscureText: true,
        maxLength: 20,
        prefix: const Icon(Icons.lock_outline),
        suffix: const Icon(Icons.visibility_outlined),
      ),
    ]),
  );
  mcGoldenMatrix(
    acId: ac,
    component: 'text_field_german',
    height: 200,
    heightAtScale2: 320,
    builder: (_) => _pad([
      McTextField(
        controller: _c(),
        label: _german,
        helperText: 'Hilfetext: $_german',
        errorText: 'Fehler: $_german',
      ),
    ]),
  );
  mcGoldenMatrix(
    acId: ac,
    component: 'search_field_empty',
    height: 120,
    heightAtScale2: 120,
    builder: (_) => _pad([
      McSearchField(
        controller: _c(),
        label: 'Search characters',
        clearLabel: 'Clear search',
      ),
    ]),
  );
  mcGoldenMatrix(
    acId: ac,
    component: 'search_field_filled',
    height: 120,
    heightAtScale2: 120,
    builder: (_) => _pad([
      McSearchField(
        controller: _c('spider'),
        label: 'Search characters',
        clearLabel: 'Clear search',
      ),
    ]),
  );
  mcGoldenMatrix(
    acId: ac,
    component: 'search_field_focused',
    height: 120,
    heightAtScale2: 120,
    builder: (_) => _pad([
      McSearchField(
        controller: _c('spid'),
        label: 'Search characters',
        clearLabel: 'Clear search',
        autofocus: true,
      ),
    ]),
  );
  mcGoldenMatrix(
    acId: ac,
    component: 'search_field_disabled',
    height: 120,
    heightAtScale2: 120,
    builder: (_) => _pad([
      McSearchField(
        controller: _c(),
        label: 'Search characters',
        clearLabel: 'Clear search',
        enabled: false,
      ),
    ]),
  );
  mcGoldenMatrix(
    acId: ac,
    component: 'chip_states',
    height: 240,
    heightAtScale2: 420,
    builder: (_) => _pad([
      Wrap(
        spacing: 8,
        children: [
          McChip(label: 'Unselected', selected: false, onSelected: (_) {}),
          McChip(label: 'Selected', selected: true, onSelected: (_) {}),
          McChip(
            label: 'With icon',
            icon: Icons.bolt,
            selected: false,
            onSelected: (_) {},
          ),
          const McChip(label: 'Disabled', selected: false, onSelected: null),
          const McChip(
            label: 'Disabled selected',
            selected: true,
            onSelected: null,
          ),
          McChip(label: _german, selected: true, onSelected: (_) {}),
        ],
      ),
    ]),
  );
  mcGoldenMatrix(
    acId: ac,
    component: 'chip_group_single',
    height: 200,
    heightAtScale2: 400,
    builder: (_) => _pad([
      McChipGroup<String>.single(
        options: _options,
        selected: 'b',
        onChanged: (_) {},
      ),
    ]),
  );
  mcGoldenMatrix(
    acId: ac,
    component: 'chip_group_multi',
    height: 200,
    heightAtScale2: 400,
    builder: (_) => _pad([
      McChipGroup<String>.multi(
        options: _options,
        selected: const {'a', 'c'},
        onChanged: (_) {},
      ),
    ]),
  );
  mcGoldenMatrix(
    acId: ac,
    component: 'chip_group_disabled',
    height: 200,
    heightAtScale2: 400,
    builder: (_) => _pad([
      McChipGroup<String>.multi(
        options: _options,
        selected: const {'a'},
        onChanged: null,
      ),
    ]),
  );
  mcGoldenMatrix(
    acId: ac,
    component: 'segmented_2',
    height: 100,
    heightAtScale2: 100,
    builder: (_) => _pad([
      McSegmented(
        segments: const [
          McSegment(label: 'Grid'),
          McSegment(label: 'List'),
        ],
        selectedIndex: 0,
        onChanged: (_) {},
      ),
    ]),
  );
  mcGoldenMatrix(
    acId: ac,
    component: 'segmented_5',
    height: 130,
    heightAtScale2: 220,
    builder: (_) => _pad([
      McSegmented(
        segments: const [
          McSegment(label: 'Alle'),
          McSegment(label: 'Helden'),
          McSegment(label: 'Größte'),
          McSegment(label: 'Neu'),
          McSegment(label: 'Mehr'),
        ],
        selectedIndex: 2,
        onChanged: (_) {},
      ),
    ]),
  );
  mcGoldenMatrix(
    acId: ac,
    component: 'segmented_german',
    height: 160,
    heightAtScale2: 300,
    builder: (_) => _pad([
      McSegmented(
        segments: const [
          McSegment(label: 'Zuletzt hinzugefügt'),
          McSegment(label: 'Geschwindigkeit'),
          McSegment(label: _german),
        ],
        selectedIndex: 1,
        onChanged: (_) {},
      ),
    ]),
  );
  mcGoldenMatrix(
    acId: ac,
    component: 'segmented_disabled',
    height: 100,
    heightAtScale2: 100,
    builder: (_) => _pad([
      McSegmented(
        segments: const [
          McSegment(label: 'Grid', icon: Icons.grid_view),
          McSegment(label: 'List', icon: Icons.view_list),
        ],
        selectedIndex: 1,
        onChanged: null,
      ),
    ]),
  );
  mcGoldenMatrix(
    acId: ac,
    component: 'stepper_states',
    height: 290,
    heightAtScale2: 290,
    builder: (_) => _pad([
      Align(alignment: Alignment.centerLeft, child: _stepper(3)),
      Align(alignment: Alignment.centerLeft, child: _stepper(0)),
      Align(alignment: Alignment.centerLeft, child: _stepper(5)),
      Align(
        alignment: Alignment.centerLeft,
        child: _stepper(3, enabled: false),
      ),
    ]),
  );
}
