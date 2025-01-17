import pandas as pd
import numpy as np

df = pd.read_csv('output.txt', delimiter="               ", names=["TIME", "EPBAR", "S11", "S22", "S33", "S12", "S13", "S23", "YF", "HF", "AA", "BB", "CC", "NRK"], dtype="float")
df["SWIFT"] = df["AA"] * np.power(( df["BB"] + df["EPBAR"]), df["CC"])
filename = "output.xlsx"
df.to_excel(filename, index=False, float_format="%.8f")