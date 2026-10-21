import sys

sys.path.append(r'C:\Python310\Lib\site-packages')
import numpy as np
from scipy import integrate
import pandas as pd
import os
from openpyxl import load_workbook
from openpyxl.utils import get_column_letter
import warnings

warnings.filterwarnings('ignore')


def solve_simple_10eq(params):
    """输入34个速率常数，求解10个物种覆盖度"""
    if len(params) < 34:
        raise ValueError(f'需要34个参数，但只有{len(params)}个')

    A1, A2, A3, A4 = params[0], params[1], params[2], params[3]
    A5, A6, A7, A8 = params[4], params[5], params[6], params[7]
    D1, D2, D3, D4 = params[8], params[9], params[10], params[11]
    D5, D6, D7, D8 = params[12], params[13], params[14], params[15]
    V1, V2, V3, V4 = params[16], params[17], params[18], params[19]
    V5, V6, V7, V8 = params[20], params[21], params[22], params[23]
    H1, H2, H3, H4 = params[24], params[25], params[26], params[27]
    H5, H6, H7, H8 = params[28], params[29], params[30], params[31]
    T1, T2 = params[32], params[33]

    A = np.zeros((10, 10), dtype=np.float64)
    b = np.zeros(10, dtype=np.float64)

    A[0, :] = 1.0
    b[0] = 1.0

    A[1, 0] = A1
    A[1, 1] = -(A5 + A2 + V1 + D6)
    A[1, 2] = V5
    A[1, 4] = A6
    A[1, 6] = D2

    A[2, 1] = V1
    A[2, 2] = -(A3 + V5 + H1 + D7)
    A[2, 3] = H5
    A[2, 5] = A7
    A[2, 8] = D3

    A[3, 0] = D5
    A[3, 2] = H1
    A[3, 3] = -(A4 + H5 + T2 + D1 + D8)
    A[3, 6] = A8
    A[3, 7] = T1
    A[3, 9] = D4

    A[4, 1] = A2
    A[4, 4] = -(A6 + V2)
    A[4, 5] = V6

    A[5, 2] = A3
    A[5, 4] = V2
    A[5, 5] = -(A7 + V6 + V3 + H2)
    A[5, 6] = H6
    A[5, 7] = V7

    A[6, 1] = D6
    A[6, 3] = A4
    A[6, 5] = H2
    A[6, 6] = -(A8 + V4 + H6 + D2)
    A[6, 8] = V8

    A[7, 3] = T2
    A[7, 5] = V3
    A[7, 7] = -(V7 + H3 + T1)
    A[7, 8] = H7

    A[8, 2] = D7
    A[8, 6] = V4
    A[8, 7] = H3
    A[8, 8] = -(V8 + H7 + H4 + D3)
    A[8, 9] = H8

    A[9, 3] = D8
    A[9, 8] = H4
    A[9, 9] = -(H8 + D4)

    try:
        X = np.linalg.solve(A, b)
    except np.linalg.LinAlgError:
        X = np.linalg.lstsq(A, b, rcond=None)[0]
    return X


def calculate_Kw(T_K):
    """计算水的离子积 Kw，经验公式适用于 0-300°C"""
    A = -4.706
    B = 4470.0
    C = -0.0217
    D = 0.0
    pKw = A + B / T_K + C * np.log(T_K) + D * T_K
    Kw = 10.0 ** (-pKw)
    return Kw


def format_scientific(value, sig=4):
    """将数值格式化为科学计数法字符串，保留指定有效数字位数"""
    if value is None or np.isnan(value) or np.isinf(value):
        return str(value)
    try:
        return np.format_float_scientific(value, precision=sig - 1, unique=False, trim='k')
    except:
        return str(value)


def set_column_width(worksheet, width=10):
    max_col = worksheet.max_column
    for col in range(1, max_col + 1):
        col_letter = get_column_letter(col)
        worksheet.column_dimensions[col_letter].width = width


def calculate_reaction_rates_and_coverage():
    print("计算速率常数及覆盖度...")
    excel_file = "energy.xlsx"
    if not os.path.exists(excel_file):
        print(f"错误: 找不到文件 '{excel_file}'")
        return

    DEFAULT_KB = 8.617333262145e-5
    DEFAULT_H = 4.135667662e-15

    try:
        df = pd.read_excel(excel_file, sheet_name=0)
        print(f"读取到 {len(df)} 行参数")

        required_cols = ['GD1', 'GD2', 'GD3', 'GD4', 'GT']
        for col in required_cols:
            if col not in df.columns:
                df[col] = 0.0

        if 'p' not in df.columns:
            raise KeyError("Sheet1 中缺少 'p' 列")

        print("根据热力学约束计算 GD1~GD4 和 GT...")
        gd_values = {col: [] for col in required_cols}
        for idx, row in df.iterrows():
            GA1, GA2, GA3, GA4 = row['GA1'], row['GA2'], row['GA3'], row['GA4']
            GV1, GV2, GV3, GV4 = row['GV1'], row['GV2'], row['GV3'], row['GV4']
            GH1, GH2, GH3, GH4 = row['GH1'], row['GH2'], row['GH3'], row['GH4']

            T = row['T']
            a_H = row['a_H']
            p_H2 = row['p']
            kB = float(row.get('kB', DEFAULT_KB))

            if p_H2 <= 0 or a_H <= 0:
                raise ValueError(f"第 {idx + 1} 行: p_H2 或 a_H 为非正数")
            deltaG0 = kB * T * (np.log(p_H2) - 2 * np.log(a_H))

            GD1 = deltaG0 - GA1 - GV1 - GH1
            GD2 = deltaG0 - GA2 - GV2 - GH2
            GD3 = deltaG0 - GA3 - GV3 - GH3
            GD4 = deltaG0 - GA4 - GV4 - GH4
            GT = deltaG0 - GA3 - GV3 - GD1

            gd_values['GD1'].append(GD1)
            gd_values['GD2'].append(GD2)
            gd_values['GD3'].append(GD3)
            gd_values['GD4'].append(GD4)
            gd_values['GT'].append(GT)

            df.at[idx, 'GD1'] = GD1
            df.at[idx, 'GD2'] = GD2
            df.at[idx, 'GD3'] = GD3
            df.at[idx, 'GD4'] = GD4
            df.at[idx, 'GT'] = GT

        print("正在将计算得到的 GD1~GD4 和 GT 写回 Sheet1（保留原始精度）...")
        wb = load_workbook(excel_file)
        ws = wb['Sheet1']

        header = [cell.value for cell in ws[1]]
        col_indices = {}
        for col_name in required_cols:
            if col_name in header:
                col_indices[col_name] = header.index(col_name) + 1
            else:
                new_col_idx = ws.max_column + 1
                ws.cell(row=1, column=new_col_idx, value=col_name)
                col_indices[col_name] = new_col_idx

        for i, col_name in enumerate(required_cols):
            col_idx = col_indices[col_name]
            values = gd_values[col_name]
            for row_num, val in enumerate(values, start=2):
                # 直接写入原始浮点数，不做舍入
                ws.cell(row=row_num, column=col_idx, value=val)

        wb.save(excel_file)
        print("已更新 Sheet1 中的 GD1~GD4 和 GT 列。")

        df = pd.read_excel(excel_file, sheet_name=0)

        results_list = []

        for row_idx, row in df.iterrows():
            row_result = {}

            GV = [float(row[f'GV{i}']) for i in range(1, 5)]
            GH = [float(row[f'GH{i}']) for i in range(1, 5)]
            G_values = GV + GH
            lambdaV = [float(row[f'lambdaV{i}']) for i in range(1, 5)]
            lambdaH = [float(row[f'lambdaH{i}']) for i in range(1, 5)]
            lambda_values = lambdaV + lambdaH

            eta = float(row['eta'])
            T = float(row['T'])
            a_H = float(row['a_H'])
            kB = float(row.get('kB', DEFAULT_KB))
            h = float(row.get('h', DEFAULT_H))
            prefactor = kB * T / h

            Kw = calculate_Kw(T)
            a_OH = Kw / a_H
            pH = -np.log10(a_H)
            W = -kB * T * np.log(Kw)

            for i in range(8):
                G = G_values[i]
                lam = lambda_values[i]
                charge = 1.0

                def integral_acid_forward(x, G, eta, pH, lam, T, kB):
                    ln10 = np.log(10)
                    numerator_arg = G + charge * eta - ln10 * kB * T * pH - x + lam
                    denominator = 4 * lam * kB * T
                    exponent = -(numerator_arg ** 2) / denominator
                    temp = x / (kB * T)
                    if temp > 50:
                        return np.exp(-(numerator_arg ** 2) / denominator - temp)
                    else:
                        return np.exp(exponent) / (1 + np.exp(temp))

                def integral_acid_reverse(x, G, eta, pH, lam, T, kB):
                    ln10 = np.log(10)
                    numerator_arg = -G - charge * eta + ln10 * kB * T * pH + x + lam
                    denominator = 4 * lam * kB * T
                    exponent = -(numerator_arg ** 2) / denominator
                    temp = x / (kB * T)
                    if temp > 50:
                        return np.exp(-(numerator_arg ** 2) / denominator - temp)
                    else:
                        return np.exp(exponent) / (1 + np.exp(temp))

                def integral_base_forward(x, G, eta, pH, lam, T, kB, W):
                    ln10 = np.log(10)
                    numerator_arg = G + charge * eta - ln10 * kB * T * pH + W - x + lam
                    denominator = 4 * lam * kB * T
                    exponent = -(numerator_arg ** 2) / denominator
                    temp = x / (kB * T)
                    if temp > 50:
                        return np.exp(-(numerator_arg ** 2) / denominator - temp)
                    else:
                        return np.exp(exponent) / (1 + np.exp(temp))

                def integral_base_reverse(x, G, eta, pH, lam, T, kB, W):
                    ln10 = np.log(10)
                    numerator_arg = -G - charge * eta + ln10 * kB * T * pH - W + x + lam
                    denominator = 4 * lam * kB * T
                    exponent = -(numerator_arg ** 2) / denominator
                    temp = -x / (kB * T)
                    if temp > 50:
                        return np.exp(-(numerator_arg ** 2) / denominator - temp)
                    else:
                        return np.exp(exponent) / (1 + np.exp(-x / (kB * T)))

                params_acid = (G, eta, pH, lam, T, kB)
                params_base = (G, eta, pH, lam, T, kB, W)

                integral_acid_f, _ = integrate.quad(integral_acid_forward, -np.inf, np.inf, args=params_acid)
                integral_acid_r, _ = integrate.quad(integral_acid_reverse, -np.inf, np.inf, args=params_acid)
                integral_base_f, _ = integrate.quad(integral_base_forward, -np.inf, np.inf, args=params_base)
                integral_base_r, _ = integrate.quad(integral_base_reverse, -np.inf, np.inf, args=params_base)

                k_acid_f = integral_acid_f * prefactor
                k_acid_r = integral_acid_r * prefactor
                k_base_f = integral_base_f * prefactor
                k_base_r = integral_base_r * prefactor

                forward_rate = k_acid_f * a_H + k_base_f
                reverse_rate = k_acid_r + k_base_r * a_OH

                row_result[f'R{i + 1}_正'] = forward_rate
                row_result[f'R{i + 1}_逆'] = reverse_rate

            sigma = float(row['sigma'])
            GA = [float(row[f'GA{i}']) for i in range(1, 5)]
            GD = [float(row[f'GD{i}']) for i in range(1, 5)]
            GT_val = float(row['GT'])
            dG_values = GA + GD + [GT_val]

            for i in range(9):
                dG = dG_values[i]
                exponent_term = np.log(np.exp(sigma * dG) + 1) / sigma
                k_forward = (kB * T / h) * np.exp(-exponent_term / (kB * T))
                exponent_term_reverse = np.log(np.exp(sigma * (-dG)) + 1) / sigma
                k_reverse = (kB * T / h) * np.exp(-exponent_term_reverse / (kB * T))
                row_result[f'NR{i + 1}_正'] = k_forward
                row_result[f'NR{i + 1}_逆'] = k_reverse

            results_list.append(row_result)

        rates_df = pd.DataFrame(results_list)
        print(f"速率常数计算完成，共 {len(rates_df)} 行。")

        name_mapping = {
            'R1_正': 'V1', 'R2_正': 'V2', 'R3_正': 'V3', 'R4_正': 'V4',
            'R1_逆': 'V-1', 'R2_逆': 'V-2', 'R3_逆': 'V-3', 'R4_逆': 'V-4',
            'R5_正': 'H1', 'R6_正': 'H2', 'R7_正': 'H3', 'R8_正': 'H4',
            'R5_逆': 'H-1', 'R6_逆': 'H-2', 'R7_逆': 'H-3', 'R8_逆': 'H-4',
            'NR1_正': 'A1', 'NR2_正': 'A2', 'NR3_正': 'A3', 'NR4_正': 'A4',
            'NR1_逆': 'A-1', 'NR2_逆': 'A-2', 'NR3_逆': 'A-3', 'NR4_逆': 'A-4',
            'NR5_正': 'D1', 'NR6_正': 'D2', 'NR7_正': 'D3', 'NR8_正': 'D4',
            'NR5_逆': 'D-1', 'NR6_逆': 'D-2', 'NR7_逆': 'D-3', 'NR8_逆': 'D-4',
            'NR9_正': 'T', 'NR9_逆': 'T-'
        }
        rates_output_df = rates_df.rename(columns=name_mapping)
        rates_output_df.insert(0, '组号', range(1, len(rates_output_df) + 1))

        if '速率常数' in wb.sheetnames:
            wb.remove(wb['速率常数'])
        ws_rates = wb.create_sheet('速率常数')
        for col_idx, col_name in enumerate(rates_output_df.columns, 1):
            ws_rates.cell(row=1, column=col_idx, value=col_name)
        for row_idx, row_data in enumerate(rates_output_df.itertuples(index=False), 2):
            for col_idx, value in enumerate(row_data, 1):
                if col_idx == 1:
                    ws_rates.cell(row=row_idx, column=col_idx, value=int(value))
                else:
                    ws_rates.cell(row=row_idx, column=col_idx, value=format_scientific(value, sig=4))
        set_column_width(ws_rates, width=10)

        col_to_std = {
            'NR1_正': 'A1', 'NR2_正': 'A2', 'NR3_正': 'A3', 'NR4_正': 'A4',
            'NR1_逆': 'A5', 'NR2_逆': 'A6', 'NR3_逆': 'A7', 'NR4_逆': 'A8',
            'NR5_正': 'D1', 'NR6_正': 'D2', 'NR7_正': 'D3', 'NR8_正': 'D4',
            'NR5_逆': 'D5', 'NR6_逆': 'D6', 'NR7_逆': 'D7', 'NR8_逆': 'D8',
            'R1_正': 'V1', 'R2_正': 'V2', 'R3_正': 'V3', 'R4_正': 'V4',
            'R1_逆': 'V5', 'R2_逆': 'V6', 'R3_逆': 'V7', 'R4_逆': 'V8',
            'R5_正': 'H1', 'R6_正': 'H2', 'R7_正': 'H3', 'R8_正': 'H4',
            'R5_逆': 'H5', 'R6_逆': 'H6', 'R7_逆': 'H7', 'R8_逆': 'H8',
            'NR9_正': 'T1', 'NR9_逆': 'T2'
        }

        std_order = [
            'A1', 'A2', 'A3', 'A4', 'A5', 'A6', 'A7', 'A8',
            'D1', 'D2', 'D3', 'D4', 'D5', 'D6', 'D7', 'D8',
            'V1', 'V2', 'V3', 'V4', 'V5', 'V6', 'V7', 'V8',
            'H1', 'H2', 'H3', 'H4', 'H5', 'H6', 'H7', 'H8',
            'T1', 'T2'
        ]

        print("计算覆盖度及氢气生成速率...")
        coverage_results = []
        rD1_list, rD2_list, rD3_list, rD4_list, rH2_list = [], [], [], [], []

        for idx, row in rates_df.iterrows():
            params = []
            for std_name in std_order:
                orig_col = None
                for orig, std in col_to_std.items():
                    if std == std_name:
                        orig_col = orig
                        break
                if orig_col is None:
                    raise ValueError(f'未找到标准变量 {std_name} 对应的原始列')
                params.append(float(row[orig_col]))
            try:
                X = solve_simple_10eq(params)
            except Exception as e:
                print(f"第 {idx + 1} 行覆盖度求解失败: {e}")
                X = [np.nan] * 10
            coverage_results.append(X)

            D1 = float(row['NR5_正'])
            D_1 = float(row['NR5_逆'])
            D2 = float(row['NR6_正'])
            D_2 = float(row['NR6_逆'])
            D3 = float(row['NR7_正'])
            D_3 = float(row['NR7_逆'])
            D4 = float(row['NR8_正'])
            D_4 = float(row['NR8_逆'])

            rD1 = D1 * X[3] - D_1 * X[0]
            rD2 = D2 * X[6] - D_2 * X[1]
            rD3 = D3 * X[8] - D_3 * X[2]
            rD4 = D4 * X[9] - D_4 * X[3]
            rH2 = rD1 + rD2 + rD3 + rD4

            rD1_list.append(rD1)
            rD2_list.append(rD2)
            rD3_list.append(rD3)
            rD4_list.append(rD4)
            rH2_list.append(rH2)

        coverage_df = pd.DataFrame(coverage_results, columns=[f'x{i + 1}' for i in range(10)])
        coverage_df.insert(0, '组号', range(1, len(coverage_df) + 1))
        coverage_df['rD1'] = rD1_list
        coverage_df['rD2'] = rD2_list
        coverage_df['rD3'] = rD3_list
        coverage_df['rD4'] = rD4_list
        coverage_df['rH2'] = rH2_list

        sheet_name = '覆盖度及反应速率'
        if sheet_name in wb.sheetnames:
            wb.remove(wb[sheet_name])
        ws_cov = wb.create_sheet(sheet_name)
        for col_idx, col_name in enumerate(coverage_df.columns, 1):
            ws_cov.cell(row=1, column=col_idx, value=col_name)
        for row_idx, row_data in enumerate(coverage_df.itertuples(index=False), 2):
            for col_idx, value in enumerate(row_data, 1):
                if col_idx == 1:
                    ws_cov.cell(row=row_idx, column=col_idx, value=int(value))
                else:
                    ws_cov.cell(row=row_idx, column=col_idx, value=format_scientific(value, sig=4))
        set_column_width(ws_cov, width=10)

        wb.save(excel_file)

        print(f"\n计算完成！共处理 {len(df)} 组参数。")
        print(f"速率常数已保存至 '{excel_file}' 的 '速率常数' 工作表。")
        print(f"覆盖度及反应速率已保存至 '{excel_file}' 的 '{sheet_name}' 工作表。")

        return rates_df, coverage_df

    except KeyError as e:
        print(f"错误：缺少必要的列名 {e}，请检查 Sheet1 的列名。")
        return None, None
    except Exception as e:
        print(f"错误: {e}")
        return None, None


if __name__ == "__main__":
    calculate_reaction_rates_and_coverage()