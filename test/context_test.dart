// ignore_for_file: unnecessary_lambdas
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

void main() {
  group('BuildContext', () {
    testWidgets('internal selected value is updated', (tester) async {
      final notifier = ValueNotifier([false, false, false]);

      var callCounts = <int, int>{
        0: 0,
        1: 0,
        2: 0,
      };

      Widget buildIndex(int index) {
        return Builder(builder: (c) {
          callCounts[index]++;
          final selected =
              c.select<ValueNotifier<List<bool>>, bool>((notifier) {
            return notifier.value[index];
          });
          return Text('$index $selected');
        });
      }

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => notifier,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: [
                buildIndex(0),
                buildIndex(1),
                buildIndex(2),
              ],
            ),
          ),
        ),
      );

      expect(find.text('0 false'), findsOneWidget);
      expect(callCounts[0], 1);
      expect(find.text('1 false'), findsOneWidget);
      expect(callCounts[1], 1);
      expect(find.text('2 false'), findsOneWidget);
      expect(callCounts[2], 1);

      notifier.value = [false, true, false];
      await tester.pump();

      expect(find.text('0 false'), findsOneWidget);
      expect(callCounts[0], 1);
      expect(find.text('1 true'), findsOneWidget);
      expect(callCounts[1], 2);
      expect(find.text('2 false'), findsOneWidget);
      expect(callCounts[2], 1);

      notifier.value = [false, false, false];
      await tester.pump();

      expect(find.text('0 false'), findsOneWidget);
      expect(callCounts[0], 1);
      expect(find.text('1 false'), findsOneWidget);
      expect(callCounts[1], 3);
      expect(find.text('2 false'), findsOneWidget);
      expect(callCounts[2], 1);

      notifier.value = [true, false, false];
      await tester.pump();

      expect(find.text('0 true'), findsOneWidget);
      expect(callCounts[0], 2);
      expect(find.text('1 false'), findsOneWidget);
      expect(callCounts[1], 3);
      expect(find.text('2 false'), findsOneWidget);
      expect(callCounts[2], 1);

      notifier.value = [true, false, false];
      await tester.pump();

      expect(find.text('0 true'), findsOneWidget);
      expect(callCounts[0], 2);
      expect(find.text('1 false'), findsOneWidget);
      expect(callCounts[1], 3);
      expect(find.text('2 false'), findsOneWidget);
      expect(callCounts[2], 1);
    });
    testWidgets('create can use read without being lazy', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider(create: (context) => 42),
            Provider(
              lazy: false,
              create: (context) => context.read<int>().toString(),
            ),
          ],
          child: Consumer<String>(
            builder: (c, value, _) {
              return Text(value, textDirection: TextDirection.ltr);
            },
          ),
        ),
      );

      expect(find.text('42'), findsOneWidget);
    });
    testWidgets("read can't be used inside update", (tester) async {
      await tester.pumpWidget(
        Provider.value(
          value: 42,
          child: InheritedProvider<String>(
            update: (c, _) {
              return c.read<int>().toString();
            },
            child: Consumer<String>(
              builder: (c, value, _) {
                return Text(value, textDirection: TextDirection.ltr);
              },
            ),
          ),
        ),
      );

      expect(tester.takeException(), isAssertionError);
    });
    testWidgets("read can't be used inside build", (tester) async {
      await tester.pumpWidget(
        Provider.value(
          value: 42,
          child: Builder(builder: (c) {
            c.read<int>();
            return Container();
          }),
        ),
      );

      expect(tester.takeException(), isAssertionError);
    });
    testWidgets('watch can be used inside InheritedProvider.update',
        (tester) async {
      await tester.pumpWidget(
        Provider.value(
          value: 42,
          child: InheritedProvider<String>(
            update: (c, _) {
              return c.watch<int>().toString();
            },
            child: Consumer<String>(
              builder: (c, value, _) {
                return Text(value, textDirection: TextDirection.ltr);
              },
            ),
          ),
        ),
      );
    });
    testWidgets('watch throws if used outside of build', (tester) async {
      await tester.pumpWidget(
        Provider.value(
          value: 42,
          child: Builder(
            builder: (parentContext) {
              return Builder(
                builder: (_) {
                  parentContext.watch<int>();
                  return Container();
                },
              );
            },
          ),
        ),
      );

      expect(tester.takeException(), isAssertionError);
    });
    testWidgets('watch throws if used inside didChangeDependencies',
        (tester) async {
      await tester.pumpWidget(
        Provider.value(
          value: 42,
          child: StatefulTest(
            didChangeDependencies: (c) {
              c.watch<int>();
            },
            child: Container(),
          ),
        ),
      );

      expect(tester.takeException(), isAssertionError);
    });
    testWidgets(
        "select doesn't fail if it loads a provider that depends on other providers",
        (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider(create: (_) => 42),
            ProxyProvider<int, String>(
              create: (c) => '${c.read<int>()}',
              update: (c, _, __) => '${c.watch<int>() * 2}',
            ),
          ],
          child: Builder(
            builder: (context) {
              final value = context.select((String value) => value);
              return Text(value, textDirection: TextDirection.ltr);
            },
          ),
        ),
      );

      expect(find.text('84'), findsOneWidget);
    });
    testWidgets("don't call old selectors if the child rebuilds individually",
        (tester) async {
      final notifier = ValueNotifier(0);

      var buildCount = 0;
      final selector = MockSelector.identity<ValueNotifier<int>>();
      final child = Builder(builder: (c) {
        buildCount++;
        c.select<ValueNotifier<int>, ValueNotifier<int>>((v) {
          return selector(v);
        });
        return Container();
      });

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: notifier,
          child: child,
        ),
      );

      expect(buildCount, 1);
      verify(selector(notifier)).called(1);
      verifyNoMoreInteractions(selector);

      tester.element(find.byWidget(child)).markNeedsBuild();
      await tester.pump();

      expect(buildCount, 2);
      verify(selector(notifier)).called(1);
      verifyNoMoreInteractions(selector);

      notifier.notifyListeners();
      await tester.pump();

      expect(buildCount, 2);
      verify(selector(notifier)).called(1);
      verifyNoMoreInteractions(selector);
    });
    testWidgets('selects throws inside click handlers', (tester) async {
      await tester.pumpWidget(
        Provider.value(
          value: 42,
          child: Builder(builder: (context) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                context.select((int a) => a);
              },
              child: Container(),
            );
          }),
        ),
      );

      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(GestureDetector));

      expect(tester.takeException(), isAssertionError);
    });
    testWidgets('select throws if try to read dynamic', (tester) async {
      await tester.pumpWidget(
        Builder(builder: (c) {
          c.select<dynamic, dynamic>((dynamic i) => i);
          return Container();
        }),
      );

      expect(tester.takeException(), isAssertionError);
    });
    testWidgets('select throws ProviderNotFoundException', (tester) async {
      await tester.pumpWidget(
        Builder(builder: (c) {
          c.select((int i) => i);
          return Container();
        }),
      );

      expect(tester.takeException(), isA<ProviderNotFoundException>());
    });
    testWidgets('select throws if watch called inside the callback from build',
        (tester) async {
      await tester.pumpWidget(
        Provider.value(
          value: 42,
          child: Builder(builder: (context) {
            context.select((int i) {
              context.watch<int>();
              return i;
            });
            return Container();
          }),
        ),
      );

      expect(tester.takeException(), isAssertionError);
    });
    testWidgets('select throws if read called inside the callback from build',
        (tester) async {
      await tester.pumpWidget(
        Provider.value(
          value: 42,
          child: Builder(builder: (context) {
            context.select((int i) {
              context.read<int>();
              return i;
            });
            return Container();
          }),
        ),
      );

      expect(tester.takeException(), isAssertionError);
    });
    testWidgets('select throws if select called inside the callback from build',
        (tester) async {
      await tester.pumpWidget(
        Provider.value(
          value: 42,
          child: Builder(builder: (context) {
            context.select((int i) {
              context.select((int i) => i);
              return i;
            });
            return Container();
          }),
        ),
      );

      expect(tester.takeException(), isAssertionError);
    });
    testWidgets(
        'select throws if read called inside the callback on dependency change',
        (tester) async {
      var shouldCall = false;
      var child = Builder(builder: (context) {
        context.select((int i) {
          if (shouldCall) {
            context.read<int>();
          }
          // trigger selector call without rebuilding
          return 0;
        });
        return const Text('foo', textDirection: TextDirection.ltr);
      });

      await tester.pumpWidget(
        Provider.value(
          value: 42,
          child: child,
        ),
      );

      expect(find.text('foo'), findsOneWidget);
      shouldCall = true;
      await tester.pumpWidget(
        Provider.value(
          value: 21,
          child: child,
        ),
      );

      expect(tester.takeException(), isAssertionError);
    });
    testWidgets(
        'select throws if watch called inside the callback on dependency change',
        (tester) async {
      var shouldCall = false;
      var child = Builder(builder: (context) {
        context.select((int i) {
          if (shouldCall) {
            context.watch<int>();
          }
          // trigger selector call without rebuilding
          return 0;
        });
        return const Text('foo', textDirection: TextDirection.ltr);
      });

      await tester.pumpWidget(
        Provider.value(
          value: 42,
          child: child,
        ),
      );

      expect(find.text('foo'), findsOneWidget);
      shouldCall = true;
      await tester.pumpWidget(
        Provider.value(
          value: 21,
          child: child,
        ),
      );

      expect(tester.takeException(), isAssertionError);
    });
    testWidgets(
        'select throws if select called inside the callback on dependency change',
        (tester) async {
      var shouldCall = false;
      var child = Builder(builder: (context) {
        context.select((int i) {
          if (shouldCall) {
            context.select((int i) => i);
          }
          // trigger selector call without rebuilding
          return 0;
        });
        return const Text('foo', textDirection: TextDirection.ltr);
      });

      await tester.pumpWidget(
        Provider.value(
          value: 42,
          child: child,
        ),
      );

      expect(find.text('foo'), findsOneWidget);
      shouldCall = true;
      await tester.pumpWidget(
        Provider.value(
          value: 21,
          child: child,
        ),
      );

      expect(tester.takeException(), isAssertionError);
    });
    testWidgets('can call read inside didChangeDependencies', (tester) async {
      await tester.pumpWidget(
        Provider.value(
          value: 42,
          child: StatefulTest(
            didChangeDependencies: (context) {
              context..read<int>();
            },
            child: const Text('42', textDirection: TextDirection.ltr),
          ),
        ),
      );

      expect(find.text('42'), findsOneWidget);
    });
    testWidgets(
        'select in didChangeDependencies stops working if build uses select too',
        (tester) async {
      var didChangeDependenciesCount = 0;
      var selectorCount = 0;
      var child = StatefulTest(
        didChangeDependencies: (c) {
          didChangeDependenciesCount++;
          c.select((int i) {
            selectorCount++;
            return i;
          });
        },
        builder: (context) {
          // never trigger a rebuild in itself, but still clear selectors
          context.select((int i) => 0);
          return Container();
        },
      );

      await tester.pumpWidget(
        Provider.value(
          value: 42,
          child: child,
        ),
      );

      expect(selectorCount, 1);
      expect(didChangeDependenciesCount, 1);

      tester.element(find.byType(StatefulTest)).markNeedsBuild();
      await tester.pump();

      expect(selectorCount, 1);
      expect(didChangeDependenciesCount, 1);

      await tester.pumpWidget(
        Provider.value(
          value: 21,
          child: child,
        ),
      );

      // selectors in `didChangeDependencies` where cleared
      expect(selectorCount, 1);
      expect(didChangeDependenciesCount, 1);
    });
    testWidgets('select in initState throws', (tester) async {
      await tester.pumpWidget(
        Provider.value(
          value: 42,
          child: StatefulTest(
            initState: (c) {
              c.select((int i) => i);
            },
            child: Container(),
          ),
        ),
      );

      expect(tester.takeException(), isAssertionError);
    });
    testWidgets('watch in initState throws', (tester) async {
      await tester.pumpWidget(
        Provider.value(
          value: 42,
          child: StatefulTest(
            initState: (c) {
              c.watch<int>();
            },
            child: Container(),
          ),
        ),
      );

      expect(tester.takeException(), isAssertionError);
    });
    testWidgets('read in initState works', (tester) async {
      int value;
      await tester.pumpWidget(
        Provider.value(
          value: 42,
          child: StatefulTest(
            initState: (c) {
              value = c.read<int>();
            },
            child: Container(),
          ),
        ),
      );

      expect(value, 42);
    });
    testWidgets('consumer can be removed and selector stops to be called',
        (tester) async {
      final selector = MockSelector.identity<int>();

      final child = Builder(builder: (c) {
        c.select<int, int>((v) {
          return selector(v);
        });
        return Container();
      });

      await tester.pumpWidget(
        Provider.value(
          value: 0,
          child: child,
        ),
      );

      verify(selector(0)).called(1);
      verifyNoMoreInteractions(selector);

      await tester.pumpWidget(
        Provider.value(
          value: 42,
          child: Container(),
        ),
      );

      // necessary call because didChangeDependencies may be called even
      // if the widget will be unmounted in the same frame
      verify(selector(42)).called(1);
      verifyNoMoreInteractions(selector);

      await tester.pumpWidget(
        Provider.value(
          value: 84,
          child: Container(),
        ),
      );

      verifyNoMoreInteractions(selector);
    });
    testWidgets('context.select deeply compares maps', (tester) async {
      final notifier = ValueNotifier(<int, int>{});

      var buildCount = 0;
      final selector = MockSelector.identity<Map<int, int>>();
      final child = Builder(builder: (c) {
        buildCount++;
        c.select<Map<int, int>, Map<int, int>>((v) {
          return selector(v);
        });
        return Container();
      });

      await tester.pumpWidget(
        ValueListenableProvider.value(
          value: notifier,
          child: child,
        ),
      );

      expect(buildCount, 1);
      verify(selector(notifier.value)).called(1);
      verifyNoMoreInteractions(selector);

      notifier.value = {0: 0, 1: 1};
      await tester.pump();

      expect(buildCount, 2);
      verify(selector(notifier.value)).called(2);
      verifyNoMoreInteractions(selector);

      notifier.value = {0: 0, 1: 1};

      await tester.pump();

      expect(buildCount, 2);
      verify(selector(notifier.value)).called(1);
      verifyNoMoreInteractions(selector);
    });
    testWidgets('context.select deeply compares lists', (tester) async {
      final notifier = ValueNotifier(<int>[]);

      var buildCount = 0;
      final selector = MockSelector.identity<List<int>>();
      final child = Builder(builder: (c) {
        buildCount++;
        c.select<List<int>, List<int>>((v) {
          return selector(v);
        });
        return Container();
      });

      await tester.pumpWidget(
        ValueListenableProvider.value(
          value: notifier,
          child: child,
        ),
      );

      expect(buildCount, 1);
      verify(selector(notifier.value)).called(1);
      verifyNoMoreInteractions(selector);

      notifier.value = [0, 1];
      await tester.pump();

      expect(buildCount, 2);
      verify(selector(notifier.value)).called(2);
      verifyNoMoreInteractions(selector);

      notifier.value = [0, 1];
      await tester.pump();

      expect(buildCount, 2);
      verify(selector(notifier.value)).called(1);
      verifyNoMoreInteractions(selector);
    });
    testWidgets('context.select deeply compares iterables', (tester) async {
      final notifier = ValueNotifier<Iterable<int>>(<int>[]);

      var buildCount = 0;
      final selector = MockSelector.identity<Iterable<int>>();
      final child = Builder(builder: (c) {
        buildCount++;
        c.select<Iterable<int>, Iterable<int>>((v) {
          return selector(v);
        });
        return Container();
      });

      await tester.pumpWidget(
        ValueListenableProvider.value(
          value: notifier,
          child: child,
        ),
      );

      expect(buildCount, 1);
      verify(selector(notifier.value)).called(1);
      verifyNoMoreInteractions(selector);

      notifier.value = [0, 1];
      await tester.pump();

      expect(buildCount, 2);
      verify(selector(notifier.value)).called(2);
      verifyNoMoreInteractions(selector);

      notifier.value = [0, 1];
      await tester.pump();

      expect(buildCount, 2);
      verify(selector(notifier.value)).called(1);
      verifyNoMoreInteractions(selector);
    });
    testWidgets('context.select deeply compares sets', (tester) async {
      final notifier = ValueNotifier<Set<int>>(<int>{});

      var buildCount = 0;
      final selector = MockSelector.identity<Set<int>>();
      final child = Builder(builder: (c) {
        buildCount++;
        c.select<Set<int>, Set<int>>((v) {
          return selector(v);
        });
        return Container();
      });

      await tester.pumpWidget(
        ValueListenableProvider.value(
          value: notifier,
          child: child,
        ),
      );

      expect(buildCount, 1);
      verify(selector(notifier.value)).called(1);
      verifyNoMoreInteractions(selector);

      notifier.value = {0, 1};
      await tester.pump();

      expect(buildCount, 2);
      verify(selector(notifier.value)).called(2);
      verifyNoMoreInteractions(selector);

      notifier.value = {0, 1};
      await tester.pump();

      expect(buildCount, 2);
      verify(selector(notifier.value)).called(1);
      verifyNoMoreInteractions(selector);
    });
    testWidgets('context.watch listens to value changes', (tester) async {
      final child = Builder(builder: (context) {
        final value = context.watch<int>();
        return Text('$value', textDirection: TextDirection.ltr);
      });

      await tester.pumpWidget(
        Provider.value(
          value: 42,
          child: child,
        ),
      );

      expect(find.text('42'), findsOneWidget);

      await tester.pumpWidget(
        Provider.value(
          value: 24,
          child: child,
        ),
      );

      expect(find.text('24'), findsOneWidget);
    });
  });
  testWidgets('clears select dependencies for all dependents', (tester) async {
    var buildCountChild1 = 0;
    var buildCountChild2 = 0;

    final select1 = MockSelector<int, int>((v) => 0);
    final select2 = MockSelector<int, int>((v) => 0);

    Widget build(int value) {
      return Provider.value(
        value: value,
        child: Stack(
          textDirection: TextDirection.ltr,
          children: <Widget>[
            Builder(builder: (c) {
              buildCountChild1++;
              c.select<int, int>(select1.call);
              return Container();
            }),
            Builder(builder: (c) {
              buildCountChild2++;
              c.select<int, int>(select2.call);
              return Container();
            }),
          ],
        ),
      );
    }

    await tester.pumpWidget(build(0));

    expect(buildCountChild1, 1);
    expect(buildCountChild2, 1);
    verify(select1(0)).called(1);
    verifyNoMoreInteractions(select1);
    verify(select2(0)).called(1);
    verifyNoMoreInteractions(select2);

    await tester.pumpWidget(build(1));

    expect(buildCountChild1, 2);
    expect(buildCountChild2, 2);
    verify(select1(1)).called(2);
    verifyNoMoreInteractions(select1);
    verify(select2(1)).called(2);
    verifyNoMoreInteractions(select2);

    await tester.pumpWidget(build(2));

    expect(buildCountChild1, 3);
    expect(buildCountChild2, 3);
    verify(select1(2)).called(2);
    verifyNoMoreInteractions(select1);
    verify(select2(2)).called(2);
    verifyNoMoreInteractions(select2);
  });
}

class StatefulTest extends StatefulWidget {
  StatefulTest({
    Key key,
    this.initState,
    this.child,
    this.didChangeDependencies,
    this.builder,
    this.dispose,
  }) : super(key: key);

  final void Function(BuildContext c) initState;
  final void Function(BuildContext c) didChangeDependencies;
  final WidgetBuilder builder;
  final Widget child;
  final void Function(BuildContext c) dispose;

  @override
  _StatefulTestState createState() => _StatefulTestState();
}

class _StatefulTestState extends State<StatefulTest> {
  @override
  void initState() {
    super.initState();
    widget.initState?.call(context);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.didChangeDependencies?.call(context);
  }

  @override
  void dispose() {
    widget.dispose?.call(context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.builder != null) {
      return widget.builder(context);
    }
    return widget.child;
  }
}

class MockSelector<T, R> extends Mock {
  MockSelector(R cb(T v)) {
    when(this(any)).thenAnswer((i) {
      return cb(i.positionalArguments.first as T);
    });
  }

  static MockSelector<T, T> identity<T>() {
    return MockSelector<T, T>((v) => v);
  }

  R call(T v);
}
