# HER/HOR Python 动力学计算 / HER/HOR Python Kinetics

## 中文

本项目根目录包含 Python 版 HER/HOR 动力学计算程序，支持 CSV 批量计算、基线过电位扫描和近平衡区扫描。

### 安装依赖

需要 Python 3，以及以下软件包：

```powershell
python -m pip install numpy scipy pandas matplotlib
```

### 运行

在项目根目录运行：

```powershell
# 计算示例输入，结果写入 results.csv
python calculator.py --input input_template.csv --output results.csv

# 基线过电位扫描
python eta_sweep.py

# 近平衡区扫描
python near_equilibrium_sweep.py
```

`input_template.csv` 是自定义输入模板。复制示例行并填写参数；每行代表一个计算情形，可使用唯一的 `case_id`。计算程序将结果写入单独的 CSV，不会修改输入文件。

基线扫描默认从 `eta = -0.25` 到 `0.305 V`，步长 `0.005 V`；近平衡区扫描默认使用 `p = 0.1`、`a_H = 1.0`，从 `eta = -0.25` 到 `0.25 V`，步长 `0.002 V`。可通过命令行参数调整扫描范围和输出目录，详见：

```powershell
python eta_sweep.py --help
python near_equilibrium_sweep.py --help
```

运行后会在项目根目录生成输入/结果 CSV 和图像。结果文件可重新生成，默认由 `.gitignore` 排除；需要留档时请另行备份。

## English

The repository root contains the Python HER/HOR kinetics tools for CSV batch calculations, a baseline overpotential sweep, and a near-equilibrium sweep.

### Install dependencies

Python 3 and the following packages are required:

```powershell
python -m pip install numpy scipy pandas matplotlib
```

### Run

Run these commands from the repository root:

```powershell
# Calculate the example input and write results to results.csv
python calculator.py --input input_template.csv --output results.csv

# Baseline overpotential sweep
python eta_sweep.py

# Near-equilibrium sweep
python near_equilibrium_sweep.py
```

Use `input_template.csv` as a template for custom inputs. Duplicate and edit the example row; each row represents one case and can have a unique `case_id`. The calculator writes results to a separate CSV and does not modify the input.

The baseline sweep defaults to `eta = -0.25` through `0.305 V` in 0.005 V increments. The near-equilibrium sweep defaults to `p = 0.1`, `a_H = 1.0`, and `eta = -0.25` through `0.25 V` in 0.002 V increments. Customize scan ranges and output directories with command-line options; see:

```powershell
python eta_sweep.py --help
python near_equilibrium_sweep.py --help
```

The scripts write scan/input CSV files, results, and plots to the repository root. These generated files can be recreated and are excluded by `.gitignore`; back them up separately if needed.

