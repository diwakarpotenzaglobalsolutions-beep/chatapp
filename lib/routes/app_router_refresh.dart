import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AppRouterRefresh extends ChangeNotifier {
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  AppRouterRefresh(List<Stream<dynamic>> streams) {
    for (final stream in streams) {
      _subscriptions.add(stream.listen((_) => notifyListeners()));
    }
  }

  factory AppRouterRefresh.fromBlocs(List<BlocBase<dynamic>> blocs) {
    return AppRouterRefresh(blocs.map((bloc) => bloc.stream).toList());
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }
}
