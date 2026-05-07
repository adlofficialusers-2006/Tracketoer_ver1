# Transport mode model

Train from the NATPAC-style feature dataset:

```powershell
python ml/train_transport_mode_model.py --csv E:\ADL\ML\data.csv --out assets\models
```

The script writes:

- `model.pkl` for Python/server-side reuse.
- `transport_mode_model.json` for the Flutter on-device predictor.
- `training_summary.json` and `tree_rules.txt` for model review.

Current training run: 5,000 rows, four labels, 89.2% holdout accuracy, 89.3% mean five-fold cross-validation accuracy.
