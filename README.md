# HER/HOR Python 动力学计算

##

本项目根目录包含 Python 版 HER/HOR 动力学计算程序，支持 CSV 批量计算、基线过电位扫描和近平衡区扫描。

### 动力学模型理论

程序计算的是基于基元反应网络的稳态微观动力学：先由输入参数得到各步正、逆速率常数，再对表面吸附物种建立稳态物料衡算，并用覆盖度总和为 1 的归一化条件求解。程序提供两种机理：

**单个位点简化模型（不含 Tafel）**将表面视为等价位点，采用吸附水逐步转化为吸附氢、吸附氢分子并脱附的可逆链路：

```text
* + H₂O          ⇌ *H₂O                  吸附 A
*H₂O + H⁺ + e⁻   ⇌ *H + H₂O              Volmer V
*H + H⁺ + e⁻     ⇌ *H₂                   Heyrovsky H
*H₂              ⇌ * + H₂                脱附 D
```

稳态未知量为 `θ*`、`θH₂O`、`θH` 和 `θH₂`，通过四阶线性方程组及 `θ* + θH₂O + θH + θH₂ = 1` 求解。净氢气生成速率定义为净脱附速率：

```text
rH₂ = kD · θH₂ − kD,reverse · θ*
```

**相邻双位点复杂模型**将两个相邻吸附位点作为一个耦合反应单元，考虑单占位和双占位中间体，以及相邻吸附氢之间的 Tafel 偶联。模型有 10 种表面状态和 17 类基元反应：4 类吸附、4 类 Volmer、4 类 Heyrovsky、4 类脱附，以及 1 类 Tafel 反应。对 10 种状态建立稳态方程并加入覆盖度归一化，求解十阶线性方程组；总速率为四个脱附通道净速率之和。该模型因此能够体现第二个吸附物种对位点占据的影响，以及 Tafel 反应对相邻位点的要求。

**速率常数与热力学约束：**

- 吸附、脱附及 Tafel 等非电子转移步骤使用 Softplus 形式的活化能和 Arrhenius 关系。Softplus 避免简单线性自由能关系在接近零或强驱动区间产生不合理的负活化能。
- Volmer 和 Heyrovsky 等电子转移步骤使用 Marcus–Gerischer 理论的数值积分形式；正、逆向速率考虑酸式和碱式贡献。
- 反应自由能遵循热力学循环约束。总反应自由能由温度、氢气分压和氢离子活度给出：`ΔG₀ = kBT [ln(p) − 2 ln(a_H)]`；未独立输入的脱附及 Tafel 自由能由循环关系推导。

**双模型比较时的参数含义：**`T`、`p`、`a_H`、`sigma` 和 `eta` 扫描点由两种模型共享；单个位点模型的 `GA_simple`、`GV_simple`、`GH_simple`、`lambdaV_simple`、`lambdaH_simple` 是独立输入，不会自动从复杂模型的四组参数中选取或平均。因而比较结果表示给定这两套参数下的模型结果，并不自动保证两模型具有相同的基元反应自由能。过电位扫描中，两模型在每个相同的 `eta` 点分别计算。

模型是用于机理分析的简化微观动力学描述；例如，模型没有显式考虑吸附物种相互作用、位点能垒分布或双电层结构，`sigma` 也需要结合具体体系选择。计算结果应结合所用参数和这些假设解释。

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

# 同一过电位扫描下比较两种模型
python comparison_sweep.py
```

### 测试

根目录下的 `test_model_comparison.py` 用于验证单个位点模型的稳态覆盖度与净脱附速率、双模型扫描输出，以及复杂模型示例结果未发生回归。测试不是计算程序运行所必需的，但建议保留，以便修改后检查核心行为。安装项目依赖后，可在根目录运行：

```powershell
python -m unittest test_model_comparison
```

`input_template.csv` 是自定义输入模板。复制示例行并填写参数；每行代表一个计算情形，可使用唯一的 `case_id`。计算程序将结果写入单独的 CSV，不会修改输入文件。

基线扫描默认从 `eta = -0.25` 到 `0.305 V`，步长 `0.005 V`；近平衡区扫描默认使用 `p = 0.1`、`a_H = 1.0`，从 `eta = -0.25` 到 `0.25 V`，步长 `0.002 V`。可通过命令行参数调整扫描范围和输出目录，详见：

```powershell
python eta_sweep.py --help
python near_equilibrium_sweep.py --help
python comparison_sweep.py --help
```

`comparison_sweep.py` 在同一组温度、压力、活度和过电位点上分别计算单个位点模型（不含 Tafel）与相邻双位点模型，并将两者的 `rH2` 放在同一结果 CSV 中。输入模板含有单个位点专属列 `GA_simple`、`GV_simple`、`GH_simple`、`lambdaV_simple` 和 `lambdaH_simple`。扫描范围也可通过 `--eta-start`、`--eta-stop` 和 `--eta-step` 设置。

比较扫描默认运行 `eta = -0.25` 到 `0.25 V`，步长 `0.005 V`，结果写入 `comparison_results.csv`。输入 CSV 的每一行是一组参数，输出为每个参数组、每个 `eta` 一行，同时包含 `rH2_single_site` 与 `rH2_dual_site`。模板中的单个位点参数是独立列；示例数值与复杂模型第 1 组相同，但程序不会自动从复杂模型参数推导它们。

例如，可用 `python comparison_sweep.py --eta-start -0.3 --eta-stop 0.3 --eta-step 0.002 --output my_comparison.csv` 自定义扫描。输入表中的 `eta` 列会被扫描点覆盖。

运行后会在项目根目录生成输入/结果 CSV 和图像。结果文件可重新生成，默认由 `.gitignore` 排除；需要留档时请另行备份。

##

The repository root contains the Python HER/HOR kinetics tools for CSV batch calculations, a baseline overpotential sweep, and a near-equilibrium sweep.

### Kinetic-model theory

The calculator implements steady-state microkinetics based on an elementary-reaction network. It obtains forward and reverse rate constants from the input parameters, writes steady-state material balances for the adsorbed surface species, and solves them together with a coverage normalization condition. Two mechanisms are available:

**The simplified single-site model (without Tafel)** treats surface sites as equivalent and uses a reversible sequence from water adsorption through adsorbed hydrogen and hydrogen molecules to desorption:

```text
* + H₂O          ⇌ *H₂O                  adsorption A
*H₂O + H⁺ + e⁻   ⇌ *H + H₂O              Volmer V
*H + H⁺ + e⁻     ⇌ *H₂                   Heyrovsky H
*H₂              ⇌ * + H₂                desorption D
```

The steady-state unknowns are `θ*`, `θH₂O`, `θH`, and `θH₂`. They are obtained from a four-state linear system and `θ* + θH₂O + θH + θH₂ = 1`. The net hydrogen-production rate is defined as the net desorption rate:

```text
rH₂ = kD · θH₂ − kD,reverse · θ*
```

**The adjacent dual-site model** treats two neighboring adsorption sites as a coupled reaction unit. It includes singly and doubly occupied intermediates and Tafel coupling between neighboring adsorbed hydrogen atoms. The mechanism contains 10 surface states and 17 elementary-reaction classes: 4 adsorption, 4 Volmer, 4 Heyrovsky, 4 desorption, and 1 Tafel reaction. Ten steady-state equations plus coverage normalization form a linear system; the total rate is the sum of the net rates of the four desorption pathways. This representation captures site blocking by a second adsorbate and the adjacency constraint on the Tafel step.

**Rate constants and thermodynamic consistency:**

- Non-electron-transfer steps such as adsorption, desorption, and Tafel use a Softplus activation-energy relation with Arrhenius kinetics. Softplus avoids unphysical negative activation energies that a simple linear free-energy relation can produce near zero or under strong driving.
- Electron-transfer steps such as Volmer and Heyrovsky use numerical integration based on Marcus–Gerischer theory; forward and reverse rates include acid and base contributions.
- Reaction free energies obey thermodynamic-cycle constraints. The overall reaction free energy is determined by temperature, hydrogen pressure, and proton activity: `ΔG₀ = kBT [ln(p) − 2 ln(a_H)]`. Desorption and Tafel free energies not supplied independently are derived from the cycle.

**Parameter meaning in a model comparison:** `T`, `p`, `a_H`, `sigma`, and each `eta` scan value are shared by both models. The single-site parameters `GA_simple`, `GV_simple`, `GH_simple`, `lambdaV_simple`, and `lambdaH_simple` are supplied independently; they are not automatically selected or averaged from the four parameter groups of the dual-site model. Thus, a comparison is between the two models under the supplied parameter sets and does not by itself guarantee identical elementary-step free energies. Both models are evaluated at the same `eta` values in a sweep.

This is a simplified microkinetic description for mechanistic analysis. For example, it does not explicitly include adsorbate interactions, distributions of site barriers, or double-layer structure; `sigma` also needs to be selected for the system of interest. Interpret calculated results in light of the input parameters and these assumptions.

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

# Compare both models over the same eta range
python comparison_sweep.py
```

### Tests

The root-level `test_model_comparison.py` checks steady-state coverages and net desorption for the single-site model, output from the two-model sweep, and regression of the example result for the dual-site model. Tests are not required to run the calculators, but are useful for checking core behavior after changes. With the project dependencies installed, run from the repository root:

```powershell
python -m unittest test_model_comparison
```

Use `input_template.csv` as a template for custom inputs. Duplicate and edit the example row; each row represents one case and can have a unique `case_id`. The calculator writes results to a separate CSV and does not modify the input.

The baseline sweep defaults to `eta = -0.25` through `0.305 V` in 0.005 V increments. The near-equilibrium sweep defaults to `p = 0.1`, `a_H = 1.0`, and `eta = -0.25` through `0.25 V` in 0.002 V increments. `comparison_sweep.py` calculates the single-site model (without Tafel) and adjacent dual-site model at the same temperature, pressure, activity, and eta values, and writes both `rH2` results to one CSV. Its input template includes dedicated single-site parameters: `GA_simple`, `GV_simple`, `GH_simple`, `lambdaV_simple`, and `lambdaH_simple`. Set `--eta-start`, `--eta-stop`, and `--eta-step` to adjust the comparison range. Customize scan ranges and output directories for the other sweeps with command-line options; use `--help` to see the available options.

The comparison sweep defaults to `eta = -0.25` through `0.25 V` in 0.005 V increments and writes `comparison_results.csv`. Each input row is one parameter set; the output has one row per parameter set and eta value, including `rH2_single_site` and `rH2_dual_site`. Single-site parameters are supplied in their own columns. The example values match group 1 of the dual-site inputs, but the program does not derive them automatically. For example, run `python comparison_sweep.py --eta-start -0.3 --eta-stop 0.3 --eta-step 0.002 --output my_comparison.csv` to customize the sweep. The input `eta` column is overridden by each scan value.

The scripts write scan/input CSV files, results, and plots to the repository root. These generated files can be recreated and are excluded by `.gitignore`; back them up separately if needed.

