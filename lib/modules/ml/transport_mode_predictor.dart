import 'dart:convert';
import 'dart:math' as math;

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
    required this.classes,
    required this.imputationValues,
    this.baseScore = 0,
    this.trees = const [],
    this.legacyTree,
  });

  final List<String> features;
  final List<String> classes;
  final Map<String, double> imputationValues;
  final double baseScore;
  final List<Map<String, dynamic>> trees;
  final Map<String, dynamic>? legacyTree;

  static Future<TransportModePredictor> loadFromAsset({
    String path = 'assets/models/transport_mode_model.json',
  }) async {
    final raw = await rootBundle.loadString(path);
    return fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static TransportModePredictor fromJson(Map<String, dynamic> json) {
    final imputation = Map<String, dynamic>.from(json['imputation'] as Map);
    final values = Map<String, dynamic>.from(imputation['values'] as Map);

    final rawXgboost = json['xgboost'];
    final xgboost = rawXgboost == null
        ? null
        : Map<String, dynamic>.from(rawXgboost as Map);
    final legacyTree = json['tree'];

    return TransportModePredictor._(
      features: List<String>.from(json['features'] as List),
      classes: List<String>.from(json['classes'] as List),
      imputationValues: values.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
      baseScore: xgboost == null ? 0 : (xgboost['baseScore'] as num).toDouble(),
      trees: xgboost == null
          ? const []
          : List<Map<String, dynamic>>.from(
              (xgboost['trees'] as List).map(
                (tree) => Map<String, dynamic>.from(tree as Map),
              ),
            ),
      legacyTree: legacyTree == null
          ? null
          : Map<String, dynamic>.from(legacyTree as Map),
    );
  }

  TransportModePrediction predict(TripFeatureSnapshot snapshot) {
    final input = snapshot.toModelInput();
    final legacyTree = this.legacyTree;
    if (legacyTree != null) return _predictLegacyTree(legacyTree, input);

    final scores = List<double>.filled(classes.length, baseScore);

    for (final entry in trees) {
      final classIndex = entry['classIndex'] as int;
      final tree = Map<String, dynamic>.from(entry['tree'] as Map);
      scores[classIndex] += _walk(tree, input);
    }

    final probabilityValues = _softmax(scores);
    var bestIndex = 0;
    for (var i = 1; i < probabilityValues.length; i += 1) {
      if (probabilityValues[i] > probabilityValues[bestIndex]) {
        bestIndex = i;
      }
    }

    final probabilities = <String, double>{
      for (var i = 0; i < classes.length; i += 1)
        classes[i]: probabilityValues[i],
    };
    final label = classes[bestIndex];

    return TransportModePrediction(
      label: label,
      displayLabel: _displayLabel(label),
      confidence: probabilityValues[bestIndex],
      probabilities: probabilities,
    );
  }

  TransportModePrediction _predictLegacyTree(
    Map<String, dynamic> tree,
    Map<String, double> input,
  ) {
    final leaf = _walkLegacyTree(tree, input);
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

  Map<String, dynamic> _walkLegacyTree(
    Map<String, dynamic> node,
    Map<String, double> input,
  ) {
    if (node['leaf'] == true) return node;

    final feature = node['feature'] as String;
    final threshold = (node['threshold'] as num).toDouble();
    final value = input[feature] ?? imputationValues[feature] ?? 0;
    final next = value <= threshold ? node['left'] : node['right'];
    return _walkLegacyTree(Map<String, dynamic>.from(next as Map), input);
  }

  double _walk(
    Map<String, dynamic> node,
    Map<String, double> input,
  ) {
    final leaf = node['leaf'];
    if (leaf != null) return (leaf as num).toDouble();

    final feature = node['split'] as String;
    final threshold = (node['split_condition'] as num).toDouble();
    final value = input[feature] ?? imputationValues[feature] ?? 0;
    final nextNodeId = value < threshold ? node['yes'] : node['no'];
    final children = List<Map<String, dynamic>>.from(
      (node['children'] as List).map(
        (child) => Map<String, dynamic>.from(child as Map),
      ),
    );
    final next = children.firstWhere(
      (child) => child['nodeid'] == nextNodeId,
      orElse: () => children.first,
    );
    return _walk(next, input);
  }

  List<double> _softmax(List<double> scores) {
    final maxScore = scores.reduce((value, element) {
      return value > element ? value : element;
    });
    final exponents = scores
        .map((score) => math.exp(score - maxScore))
        .toList();
    final total = exponents.fold<double>(0, (sum, value) => sum + value);
    return exponents.map((value) => value / total).toList();
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
