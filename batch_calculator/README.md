# HER/HOR Batch Calculator

This isolated prototype reads one parameter case per CSV row and writes numeric results to a separate CSV. It does not modify the input file.

## Run

From this directory:

```powershell
python calculator.py --input input_template.csv --output results.csv
```

Use `input_template.csv` as the column template. Duplicate the example row for each case and give each case a unique `case_id`. The required parameter columns are already present in the template. Optional columns `kB` and `h` override the built-in constants.

The result CSV includes the original parameters, calculated `GD1`-`GD4` and `GT`, forward/reverse rate constants (`T_rate` and `T_reverse_rate` for the transfer step), `x1`-`x10`, `rD1`-`rD4`, and `rH2`. Numeric values are not rounded to display precision.

Required packages: `numpy`, `scipy`, and `pandas`.

## Baseline eta plot

Run from this directory:

```powershell
python eta_sweep.py
```

This reproduces the baseline parameter set used in the previous `energy.xlsx` sweep over eta from -0.25 V to 0.305 V in 0.005 V increments. It writes `baseline_eta_scan.csv`, `baseline_eta_results.csv`, and `rH2_eta.png` here. Override the scan range with `--eta-start`, `--eta-stop`, and `--eta-step`.

The eta scan also requires `matplotlib`.

## Near-equilibrium valley

To make a focused plot of the net-rate magnitude around its zero crossing, run:

```powershell
python near_equilibrium_sweep.py
```

This uses the same baseline energies with `p=0.1`, `a_H=1.0`, and eta from -0.25 V to 0.25 V in 0.002 V increments. It writes `near_equilibrium_input.csv`, `near_equilibrium_results.csv`, `rH2_eta_Ushape.png` (the absolute net rate), and `rH2_eta_signed.png` (the signed net rate). The output CSV keeps `rH2` signed; taking its absolute value is only for the U-shaped visualization.