// lib/models/api_mode.dart

import 'package:flutter/material.dart';

enum ApiMode {
  localServer,
  runPod;

  String get label {
    switch (this) {
      case ApiMode.localServer:
        return 'Local Server';
      case ApiMode.runPod:
        return 'RunPod API';
    }
  }

  String get description {
    switch (this) {
      case ApiMode.localServer:
        return 'Connect to a local Medical LLM server';
      case ApiMode.runPod:
        return 'Connect to RunPod API for cloud inference';
    }
  }

  IconData get icon {
    switch (this) {
      case ApiMode.localServer:
        return Icons.computer;
      case ApiMode.runPod:
        return Icons.cloud;
    }
  }
}
