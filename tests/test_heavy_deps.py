import numpy as np
import pandas as pd
import torch
from sklearn.linear_model import LinearRegression


def test_numpy_pandas():
    df = pd.DataFrame({"x": np.arange(5)})
    assert df["x"].sum() == 10


def test_torch():
    assert torch.ones(3).sum().item() == 3


def test_sklearn():
    x = np.arange(10).reshape(-1, 1)
    model = LinearRegression().fit(x, 2 * x.ravel())
    assert round(model.coef_[0], 6) == 2
