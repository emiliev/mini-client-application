import 'package:mc_paging/mc_paging.dart';
import 'package:test/test.dart';

import 'support/holder_state.dart';

void main() {
  test('T-0034-AC3 a freezed state holding PagedState has the default '
      'copyWith', () {
    const sut = HolderBox(page: PagedState<int>(), label: 'a');

    final copy = sut.copyWith(label: 'b');

    expect(copy.label, 'b');
    expect(copy.page, sut.page);
  });

  test('T-0034-AC3 the deep copyWith reaches into the PagedState', () {
    const sut = HolderBox(page: PagedState<int>(items: [1]));

    final copy = sut.copyWith.page(hasReachedEnd: true, total: 1);

    expect(copy.page.items, [1]);
    expect(copy.page.hasReachedEnd, isTrue);
    expect(copy.page.total, 1);
    expect(sut.page.hasReachedEnd, isFalse);
  });

  test('T-0034-AC3 a union case holding PagedState compiles and reads', () {
    const HolderState sut = HolderState.success(PagedState<int>(items: [1, 2]));

    expect(sut.when(loading: () => 0, success: (page) => page.items.length), 2);
  });
}
