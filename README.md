# HER/HOR 动力学计算

本项目根目录包含 HER/HOR 相关动力学的模拟计算程序，支持 CSV 批量计算、基线过电位扫描和近平衡区扫描。

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