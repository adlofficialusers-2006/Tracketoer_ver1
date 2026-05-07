import 'dart:convert';

import 'package:flutter/services.dart';

import 'trip_feature_tracker.dart';

class TransportModePrediction {
  const TransportModePrediction({
    required this.label,
    required this.displayLabel,
    required this.confidence,
    required this.probabilities,
  });

  final String label;
  final String displayLabel;
  final double confidence;
  final Map<String, double> probabilities;
}

class TransportModePredictor {
  const TransportModePredictor._({
    required this.features,
    required this.imputationValues,
    required this.tree,
  });

  final List<String> features;
  final Map<String, double> imputationValues;
  final Map<String, dynamic> tree;

  static Future<TransportModePredictor> loadFromAsset({
    String path = 'assets/models/transport_mode_model.json',
  }) async {
    final raw = await rootBundle.loadString(path);
    return fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static TransportModePredictor fromJson(Map<String, dynamic> json) {
    final imputation = Map<String, dynamic>.from(json['imputation'] as Map);
    final values = Map<String, dynamic>.from(imputation['values'] as Map);

    return TransportModePredictor._(
      features: List<String>.from(json['features'] as List),
      imputationValues: values.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
      tree: Map<String, dynamic>.from(json['tree'] as Map),
    );
  }

  TransportModePrediction predict(TripFeatureSnapshot snapshot) {
    final input = snapshot.toModelInput();
    final leaf = _walk(tree, input);
    final probabilities = Map<String, dynamic>.from(
      leaf['probabilities'] as Map,
    ).map((key, value) => MapEntry(key, (value as num).toDouble()));
    final label = leaf['class'] as String;

    return TransportModePrediction(
      label: label,
      displayLabel: _displayLabel(label),
      confidence: (leaf['confidence'] as num).toDouble(),
      probabilities: probabilities,
    );
  }

  Map<String, dynamic> _walk(
    Map<String, dynamic> node,
    Map<String, double> input,
  ) {
    if (node['leaf'] == true) return node;

    final feature = node['feature'] as String;
    final threshold = (node['threshold'] as num).toDouble();
    final value = input[feature] ?? imputationValues[feature] ?? 0;
    final next = value <= threshold ? node['left'] : node['right'];
    return _walk(Map<String, dynamic>.from(next as Map), input);
  }

  String _displayLabel(String label) {
    switch (label) {
      case 'bus':
        return 'Bus';
      case 'car':
        return 'Car';
      case 'heavy_vehicle':
        return 'Heavy vehicle';
      case 'motorcycle':
        return 'Motorcycle';
      default:
        return label
            .split('_')
            .map((part) => part.isEmpty
                ? part
                : '${part[0].toUpperCase()}${part.substring(1)}')
            .join(' ');
    }
  }
}
