import 'package:flutter/material.dart';

class BaseService {
  bool isMounted(State state) => state.mounted;
  
  void safeSetState(State state, VoidCallback fn) {
    if (state.mounted) {
      state.setState(fn);
    }
  }
}