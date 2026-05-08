from __future__ import annotations

import argparse
import json
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.impute import SimpleImputer
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
from sklearn.model_selection import StratifiedKFold, cross_val_score, train_test_split
from sklearn.pipeline import Pipeline
from sklearn.tree import DecisionTreeClassifier, export_text

FEATURES = [
    "avg_speed_kmph",
    "idle_ratio",
    "acceleration_variance",
    "avg_stop_duration_sec",
    "stop_frequency_per_hr",
]
TARGET = "vehicle_type"


def node_to_dict(tree: DecisionTreeClassifier, classes: list[str], node_id: int) -> dict:
    left = int(tree.tree_.children_left[node_id])
    right = int(tree.tree_.children_right[node_id])
    values = tree.tree_.value[node_id][0]
    total = float(values.sum())
    probabilities = values / total if total else np.zeros(len(classes))

    if left == right:
        class_index = int(np.argmax(values))
        return {
            "leaf": True,
            "class": classes[class_index],
            "confidence": float(probabilities[class_index]),
            "probabilities": {
                classes[index]: float(probabilities[index])
                for index in range(len(classes))
            },
        }

    feature_index = int(tree.tree_.feature[node_id])
    return {
        "leaf": False,
        "featureIndex": feature_index,
        "feature": FEATURES[feature_index],
        "threshold": float(tree.tree_.threshold[node_id]),
        "left": node_to_dict(tree, classes, left),
        "right": node_to_dict(tree, classes, right),
    }


def train(csv_path: Path, out_dir: Path) -> dict:
    out_dir.mkdir(parents=True, exist_ok=True)
    df = pd.read_csv(csv_path).dropna(subset=[TARGET])
    for feature in FEATURES:
        df[feature] = pd.to_numeric(df[feature], errors="coerce")

    x = df[FEATURES]
    y = df[TARGET].astype(str).str.lower().str.strip()
    x_train, x_test, y_train, y_test = train_test_split(
        x,
        y,
        test_size=0.2,
        random_state=42,
        stratify=y,
    )

    model = Pipeline(
        [
            ("imputer", SimpleImputer(strategy="median")),
            (
                "tree",
                DecisionTreeClassifier(
                    max_depth=8,
                    min_samples_leaf=4,
                    class_weight="balanced",
                    random_state=42,
                ),
            ),
        ]
    )
    model.fit(x_train, y_train)
    predictions = model.predict(x_test)
    cv_scores = cross_val_score(
        model,
        x,
        y,
        cv=StratifiedKFold(n_splits=5, shuffle=True, random_state=42),
    )

    joblib.dump(model, out_dir / "model.pkl")

    imputer: SimpleImputer = model.named_steps["imputer"]
    tree: DecisionTreeClassifier = model.named_steps["tree"]
    classes = list(tree.classes_)
    model_json = {
        "modelType": "sklearn_decision_tree_classifier",
        "version": "2026-05-07",
        "target": TARGET,
        "features": FEATURES,
        "classes": classes,
        "imputation": {
            "strategy": "median",
            "values": {
                feature: float(value)
                for feature, value in zip(FEATURES, imputer.statistics_)
            },
        },
        "tree": node_to_dict(tree, classes, 0),
        "metrics": {
            "holdoutAccuracy": float(accuracy_score(y_test, predictions)),
            "crossValidationAccuracyMean": float(cv_scores.mean()),
            "crossValidationAccuracyStd": float(cv_scores.std()),
            "rows": int(len(df)),
            "trainRows": int(len(x_train)),
            "testRows": int(len(x_test)),
        },
    }
    (out_dir / "transport_mode_model.json").write_text(
        json.dumps(model_json, indent=2),
        encoding="utf-8",
    )
    (out_dir / "tree_rules.txt").write_text(
        export_text(tree, feature_names=FEATURES),
        encoding="utf-8",
    )

    summary = {
        "rows": int(len(df)),
        "labels": y.value_counts().to_dict(),
        "holdout_accuracy": model_json["metrics"]["holdoutAccuracy"],
        "cv_accuracy_mean": model_json["metrics"]["crossValidationAccuracyMean"],
        "cv_accuracy_std": model_json["metrics"]["crossValidationAccuracyStd"],
        "classification_report": classification_report(y_test, predictions),
        "confusion_matrix": confusion_matrix(y_test, predictions, labels=classes).tolist(),
        "classes": classes,
        "features": FEATURES,
    }
    (out_dir / "training_summary.json").write_text(
        json.dumps(summary, indent=2),
        encoding="utf-8",
    )
    return summary


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    summary = train(args.csv, args.out)
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
