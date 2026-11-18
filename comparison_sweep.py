import argparse
from pathlib import Path

import pandas as pd

from calculator import (
    REQUIRED_COLUMNS,
    SIMPLE_REQUIRED_COLUMNS,
    calculate_case,
    calculate_single_site_case,
)
from eta_sweep import build_scan


def run_comparison(input_path, output_path, eta_start, eta_stop, eta_step):
    input_path = Path(input_path).resolve()
    output_path = Path(output_path).resolve()
    if input_path == output_path:
        raise ValueError('Input and output paths must be different')

    data = pd.read_csv(input_path, encoding='utf-8-sig')
    required_columns = list(dict.fromkeys([*REQUIRED_COLUMNS, *SIMPLE_REQUIRED_COLUMNS]))
    missing = [column for column in required_columns if column not in data.columns]
    if missing:
        raise ValueError(f'Missing required comparison columns: {", ".join(missing)}')
    if data.empty:
        raise ValueError('Input CSV contains no parameter rows')
    if 'case_id' not in data.columns:
        data.insert(0, 'case_id', [f'case_{index + 1:06d}' for index in range(len(data))])

    eta_values = build_scan(eta_start, eta_stop, eta_step)['eta'].to_numpy(float)
    outputs = []
    for row_index, row in data.iterrows():
        case = row.to_dict()
        for eta in eta_values:
            case['eta'] = float(eta)
            try:
                single_site = calculate_single_site_case(case)
                dual_site = calculate_case(case)
            except Exception as error:
                raise ValueError(
                    f'Case {case["case_id"]} (CSV row {row_index + 2}, eta={eta:g}): {error}'
                ) from error

            result = case.copy()
            result['rH2_single_site'] = single_site['rH2']
            result['rH2_dual_site'] = dual_site['rH2']
            outputs.append(result)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    pd.DataFrame(outputs).to_csv(output_path, index=False, encoding='utf-8-sig')
    return output_path, len(outputs)


def main():
    default_dir = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(
        description='Compare single-site and adjacent dual-site HER/HOR eta sweeps'
    )
    parser.add_argument('--input', type=Path, default=default_dir / 'input_template.csv')
    parser.add_argument('--output', type=Path, default=default_dir / 'comparison_results.csv')
    parser.add_argument('--eta-start', type=float, default=-0.25)
    parser.add_argument('--eta-stop', type=float, default=0.25)
    parser.add_argument('--eta-step', type=float, default=0.005)
    args = parser.parse_args()

    output_path, row_count = run_comparison(
        args.input, args.output, args.eta_start, args.eta_stop, args.eta_step
    )
    print(f'Calculated {row_count} case/eta pairs -> {output_path}')


if __name__ == '__main__':
    main()
