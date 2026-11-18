# MATLAB HER/HOR 动力学计算 / MATLAB HER/HOR Kinetics

## 中文

本目录包含 MATLAB 版 HER/HOR 动力学实现，提供交互式入口、批量计算和过电位扫描绘图。Python 参考实现位于项目根目录；MATLAB 计算本身不依赖 Python。

### 快速运行

在 MATLAB 中打开 `RUN_ME.m`，按 F5 运行。脚本会自动将本目录加入搜索路径。修改文件开头的 `TASK` 选择任务：

| TASK | 功能 | 点数 | 参考耗时 |
|---|---|---:|---:|
| 1 | 快速曲线，`eta ∈ [-0.25, 0.25] V`，步长 0.005 | 101 | 约 1 分钟 |
| 2 | 精细曲线，步长 0.001 | 501 | 约 5 分钟 |
| 3 | 更精细曲线，步长 0.0005 | 1001 | 约 9 分钟 |
| 4 | `p = 0.1` 的曲线 | 501 | 约 5 分钟 |
| 5 | 基线过电位扫描 | 112 | 约 1 分钟 |
| 6 | 近平衡区扫描 | 251 | 约 2 分钟 |
| 7 | 批量计算本目录中的示例 CSV | 1 | 秒级 |
| 8 | 批量计算自定义 `my_input.csv` | — | — |

耗时取决于计算机和 MATLAB 版本。默认高精度覆盖度求解需要 **Symbolic Math Toolbox**。

### 文件与入口

核心文件包括：

| 文件 | 用途 |
|---|---|
| `calculate_kw.m`、`logaddexp0.m` | 水的离子积和稳定的 `ln(1+exp(z))` |
| `step_rate_integrand.m`、`integrate_step_rate.m` | 单步速率被积函数和数值积分 |
| `solve_coverages.m` | 10×10 稳态覆盖度方程组 |
| `calculate_nonideal_rates.m`、`calculate_electrochemical_rates.m` | 计算热力学速率 A/D/T 和电化学速率 V/H |
| `calculate_case.m`、`run_batch.m` | 单个情形计算及 CSV 批处理 |
| `required_columns.m`、`default_constants.m` | 必需输入列和默认常数 |
| `rate_field_order.m`、`field_to_header.m` | 速率顺序与 CSV 列名转换 |
| `baseline_parameters.m`、`build_scan.m` | 基线参数和扫描输入生成 |
| `write_csv_utf8bom.m` | 写入带 UTF-8 BOM 的 CSV |

主要入口：`run_batch(in, out)` 批量计算；`eta_sweep()` 做基线扫描；`near_equilibrium_sweep()` 做近平衡区扫描；`rH2_eta_curve()` 生成并绘制 `rH2` 随 `eta` 变化的曲线。

### 常用命令

从 MATLAB 命令窗口运行时，先添加本目录：

```matlab
addpath('path\to\HER_HOR_dynamics\matlab')
```

使用本目录中的示例输入文件进行批量计算：

```matlab
matlabDir = fileparts(which('RUN_ME'));
inputPath = fullfile(matlabDir, 'input_template.csv');
outputPath = fullfile(matlabDir, 'results.csv');
run_batch(inputPath, outputPath)
```

绘制曲线（默认扫描 501 个点）：

```matlab
rH2_eta_curve()
rH2_eta_curve('etaStep', 0.005)       % 粗步长，运行更快
rH2_eta_curve('etaStep', 0.0005)     % 细步长
rH2_eta_curve('p', 0.1, 'aH', 1.0)
```

`rH2_eta_curve` 默认在本目录生成 `rH2_eta_input.csv`、`rH2_eta_results.csv`、`rH2_eta_curve.png` 和 `rH2_eta_curve_log.png`。结果表包含 80 列；运行结束时还会报告过零点和速率极值。`eta_sweep()` 和 `near_equilibrium_sweep()` 也会在本目录生成相应的 CSV 和图像。

### 数值实现注意事项

- `solve_coverages` 默认用 60 位有效数字求解，使用 Symbolic Math Toolbox。矩阵病态，双精度可能出现负覆盖度；`'double'` 模式速度更快，但遇到不满足约束的结果会报错。
- 数值积分使用 `quadgk`，与 Python 的 `scipy.integrate.quad` 对应。
- MATLAB 结构体字段不能包含连字符，因此逆反应内部用 `Am1` 表示，写出 CSV 时会还原成 `A-1`。
- 传入覆盖度求解器的 34 个速率顺序必须为：`A1..A4, A-1..A-4, D1..D4, D-1..D-4, V1..V4, V-1..V-4, H1..H4, H-1..H-4, T_rate, T_reverse_rate`。
- 读取包含 `A-1` 等列名的 CSV 时，使用 `'VariableNamingRule','preserve'`，避免 MATLAB 改写列名。

与 Python 示例输入对拍时，列名和列顺序一致；速率常数与自由能的相对误差约为 `1e-16`。覆盖度差异通常较小，但病态系统中最小覆盖度分量的相对误差可能偏大。若分析结果敏感，请重点核对 `rH2` 等最终速率并保留计算输入。

## English

This directory contains the MATLAB HER/HOR kinetics implementation, with an interactive entry point, batch calculations, and overpotential-sweep plots. The Python reference implementation is in the repository root; the MATLAB calculations do not depend on Python.

### Quick start

Open `RUN_ME.m` in MATLAB and press F5. The script adds its directory to the MATLAB path. Change `TASK` near the top of the file to select a task:

| TASK | Function | Points | Approx. time |
|---|---|---:|---:|
| 1 | Quick curve, `eta ∈ [-0.25, 0.25] V`, step 0.005 | 101 | ~1 min |
| 2 | Fine curve, step 0.001 | 501 | ~5 min |
| 3 | Finer curve, step 0.0005 | 1001 | ~9 min |
| 4 | Curve with `p = 0.1` | 501 | ~5 min |
| 5 | Baseline overpotential sweep | 112 | ~1 min |
| 6 | Near-equilibrium sweep | 251 | ~2 min |
| 7 | Batch calculation of the local example CSV | 1 | seconds |
| 8 | Batch calculation of a custom `my_input.csv` | — | — |

Timings depend on the computer and MATLAB version. The default high-precision coverage solver requires **MATLAB Symbolic Math Toolbox**.

### Files and entry points

Core files include:

| File | Purpose |
|---|---|
| `calculate_kw.m`, `logaddexp0.m` | Water ion product and stable `ln(1+exp(z))` |
| `step_rate_integrand.m`, `integrate_step_rate.m` | Single-step rate integrand and numerical integration |
| `solve_coverages.m` | 10-by-10 steady-state coverage equations |
| `calculate_nonideal_rates.m`, `calculate_electrochemical_rates.m` | Thermodynamic A/D/T rates and electrochemical V/H rates |
| `calculate_case.m`, `run_batch.m` | Single-case calculation and CSV batch processing |
| `required_columns.m`, `default_constants.m` | Required input columns and default constants |
| `rate_field_order.m`, `field_to_header.m` | Rate ordering and CSV header conversion |
| `baseline_parameters.m`, `build_scan.m` | Baseline parameters and scan-input generation |
| `write_csv_utf8bom.m` | Write a UTF-8-BOM CSV |

Main entry points: `run_batch(in, out)` for batch calculations; `eta_sweep()` for the baseline sweep; `near_equilibrium_sweep()` for the near-equilibrium sweep; and `rH2_eta_curve()` to calculate and plot `rH2` versus `eta`.

### Common commands

From the MATLAB command window, add this directory to the path:

```matlab
addpath('path\to\HER_HOR_dynamics\matlab')
```

Use the example input stored in this directory:

```matlab
matlabDir = fileparts(which('RUN_ME'));
inputPath = fullfile(matlabDir, 'input_template.csv');
outputPath = fullfile(matlabDir, 'results.csv');
run_batch(inputPath, outputPath)
```

Plot a curve (501 points by default):

```matlab
rH2_eta_curve()
rH2_eta_curve('etaStep', 0.005)       % coarser step, faster
rH2_eta_curve('etaStep', 0.0005)     % finer step
rH2_eta_curve('p', 0.1, 'aH', 1.0)
```

By default, `rH2_eta_curve` writes `rH2_eta_input.csv`, `rH2_eta_results.csv`, `rH2_eta_curve.png`, and `rH2_eta_curve_log.png` to this directory. The result table has 80 columns. The function also reports the zero crossing and rate extrema. `eta_sweep()` and `near_equilibrium_sweep()` likewise write their CSV files and plots here.

### Numerical implementation notes

- `solve_coverages` uses 60-digit arithmetic by default and requires Symbolic Math Toolbox. The matrix is ill-conditioned; double precision may produce negative coverages. The `'double'` mode is faster but raises an error if the computed result violates the constraints.
- Numerical integration uses `quadgk`, corresponding to Python's `scipy.integrate.quad`.
- MATLAB structure fields cannot contain hyphens, so reverse-rate fields use names such as `Am1` internally and are written as `A-1` in CSV files.
- The 34 rates passed to the coverage solver must be ordered as follows: `A1..A4, A-1..A-4, D1..D4, D-1..D-4, V1..V4, V-1..V-4, H1..H4, H-1..H-4, T_rate, T_reverse_rate`.
- When reading CSV files with headers such as `A-1`, use `'VariableNamingRule','preserve'` to prevent MATLAB from changing the column names.

When checked against the Python example input, the column names and order match. Relative errors for rate constants and free energies are about `1e-16`. Coverage differences are generally small, but the relative error of the smallest coverage component may be larger in this ill-conditioned system. If the result is sensitive, verify final rates such as `rH2` and retain the calculation inputs.
