from __future__ import annotations

import argparse
import json
from pathlib import Path

import joblib
import pandas as pd
from sklearn.impute import SimpleImputer
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
from sklearn.model_selection import StratifiedKFold, cross_val_score, train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import LabelEncoder
from xgboost import XGBClassifier

FEATURES = [
    "avg_speed_kmph",
    "idle_ratio",
    "acceleration_variance",
    "avg_stop_duration_sec",
    "stop_frequency_per_hr",
]
TARGET = "vehicle_type"


def normalize_xgboost_node(node: dict) -> dict:
    normalized = dict(node)
    split = normalized.get("split")
    if isinstance(split, str) and split.startswith("f"):
        normalized["split"] = FEATURES[int(split[1:])]

    children = normalized.get("children")
    if children:
        normalized["children"] = [
            normalize_xgboost_node(child) for child in children
        ]

    return normalized


def export_xgboost_trees(model: XGBClassifier, class_count: int) -> list[dict]:
    booster = model.get_booster()
    raw_trees = [json.loads(tree) for tree in booster.get_dump(dump_format="json")]
    return [
        {
            "classIndex": index % class_count,
            "tree": normalize_xgboost_node(tree),
        }
        for index, tree in enumerate(raw_trees)
    ]


def train(csv_path: Path, out_dir: Path) -> dict:
    out_dir.mkdir(parents=True, exist_ok=True)
    df = pd.read_csv(csv_path).dropna(subset=[TARGET])
    for feature in FEATURES:
        df[feature] = pd.to_numeric(df[feature], errors="coerce")

    x = df[FEATURES]
    y = df[TARGET].astype(str).str.lower().str.strip()
    label_encoder = LabelEncoder()
    encoded_y = label_encoder.fit_transform(y)
    x_train, x_test, y_train, y_test = train_test_split(
        x,
        encoded_y,
        test_size=0.2,
        random_state=42,
        stratify=encoded_y,
    )

    model = Pipeline(
        [
            ("imputer", SimpleImputer(strategy="median")),
            (
                "xgboost",
                XGBClassifier(
                    objective="multi:softprob",
                    eval_metric="mlogloss",
                    n_estimators=120,
                    max_depth=4,
                    learning_rate=0.08,
                    subsample=0.9,
                    colsample_bytree=0.9,
                    min_child_weight=2,
                    reg_lambda=1.0,
                    random_state=42,
                    n_jobs=1,
                ),
            ),
        ]
    )
    model.fit(x_train, y_train)
    predictions = model.predict(x_test)
    cv_scores = cross_val_score(
        model,
        x,
        encoded_y,
        cv=StratifiedKFold(n_splits=5, shuffle=True, random_state=42),
    )

    joblib.dump(
        {
            "pipeline": model,
            "label_encoder": label_encoder,
        },
        out_dir / "model.pkl",
    )

    imputer: SimpleImputer = model.named_steps["imputer"]
    xgboost_model: XGBClassifier = model.named_steps["xgboost"]
    classes = [str(label) for label in label_encoder.classes_]
    model_json = {
        "modelType": "xgboost_classifier",
        "version": "2026-05-08",
        "target": TARGET,
        "features": FEATURES,
        "classes": classes,
        "xgboost": {
            "objective": "multi:softprob",
            "baseScore": float(xgboost_model.get_xgb_params().get("base_score") or 0),
            "trees": export_xgboost_trees(xgboost_model, len(classes)),
        },
        "imputation": {
            "strategy": "median",
            "values": {
                feature: float(value)
                for feature, value in zip(FEATURES, imputer.statistics_)
            },
        },
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
    (out_dir / "xgboost_trees.json").write_text(
        json.dumps(model_json["xgboost"], indent=2),
        encoding="utf-8",
    )

    decoded_y_test = label_encoder.inverse_transform(y_test)
    decoded_predictions = label_encoder.inverse_transform(predictions)
    summary = {
        "rows": int(len(df)),
        "labels": y.value_counts().to_dict(),
        "holdout_accuracy": model_json["metrics"]["holdoutAccuracy"],
        "cv_accuracy_mean": model_json["metrics"]["crossValidationAccuracyMean"],
        "cv_accuracy_std": model_json["metrics"]["crossValidationAccuracyStd"],
        "classification_report": classification_report(
            decoded_y_test,
            decoded_predictions,
        ),
        "confusion_matrix": confusion_matrix(
            decoded_y_test,
            decoded_predictions,
            labels=classes,
        ).tolist(),
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
