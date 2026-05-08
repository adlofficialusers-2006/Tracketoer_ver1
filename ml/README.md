# Transport mode model

Train from the NATPAC-style feature dataset:

```powershell
python ml/train_transport_mode_model.py --csv E:\ADL\ML\data.csv --out assets\models
```

The script writes:

- `model.pkl` for Python/server-side reuse.
- `transport_mode_model.json` for the Flutter on-device predictor.
- `training_summary.json` and `xgboost_trees.json` for model review.

The trainer uses `xgboost.XGBClassifier`, so install `xgboost` in the Python environment before retraining.
