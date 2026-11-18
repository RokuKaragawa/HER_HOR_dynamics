import argparse
from decimal import Decimal, localcontext
from pathlib import Path

import numpy as np
import pandas as pd
from scipy import integrate


DEFAULT_KB = 8.617333262145e-5
DEFAULT_H = 4.135667662e-15
REQUIRED_COLUMNS = [
    *[f'GA{i}' for i in range(1, 5)],
    *[f'GV{i}' for i in range(1, 5)],
    *[f'GH{i}' for i in range(1, 5)],
    *[f'lambdaV{i}' for i in range(1, 5)],
    *[f'lambdaH{i}' for i in range(1, 5)],
    'eta', 'T', 'p', 'a_H', 'sigma',
]


def calculate_kw(temperature):
    p_kw = -4.706 + 4470.0 / temperature - 0.0217 * np.log(temperature)
    return 10.0 ** (-p_kw)


def solve_coverages(params):
    if len(params) != 34:
        raise ValueError(f'Expected 34 rate constants, got {len(params)}')

    params = [Decimal(str(float(value))) for value in params]
    (a1, a2, a3, a4, a5, a6, a7, a8,
     d1, d2, d3, d4, d5, d6, d7, d8,
     v1, v2, v3, v4, v5, v6, v7, v8,
     h1, h2, h3, h4, h5, h6, h7, h8, t1, t2) = params

    matrix = [[Decimal(0) for _ in range(10)] for _ in range(10)]
    right = [Decimal(0) for _ in range(10)]

    def sum_rates(*values):
        with localcontext() as context:
            context.prec = 60
            return sum(values, Decimal(0))

    matrix[0] = [Decimal(1) for _ in range(10)]
    right[0] = Decimal(1)
    matrix[1][0], matrix[1][1], matrix[1][2], matrix[1][4], matrix[1][6] = (
        a1, -sum_rates(a5, a2, v1, d6), v5, a6, d2
    )
    matrix[2][1], matrix[2][2], matrix[2][3], matrix[2][5], matrix[2][8] = (
        v1, -sum_rates(a3, v5, h1, d7), h5, a7, d3
    )
    matrix[3][0], matrix[3][2], matrix[3][3] = d5, h1, -sum_rates(a4, h5, t2, d1, d8)
    matrix[3][6], matrix[3][7], matrix[3][9] = a8, t1, d4
    matrix[4][1], matrix[4][4], matrix[4][5] = a2, -sum_rates(a6, v2), v6
    matrix[5][2], matrix[5][4], matrix[5][5] = a3, v2, -sum_rates(a7, v6, v3, h2)
    matrix[5][6], matrix[5][7] = h6, v7
    matrix[6][1], matrix[6][3], matrix[6][5] = d6, a4, h2
    matrix[6][6], matrix[6][8] = -sum_rates(a8, v4, h6, d2), v8
    matrix[7][3], matrix[7][5], matrix[7][7], matrix[7][8] = (
        t2, v3, -sum_rates(v7, h3, t1), h7
    )
    matrix[8][2], matrix[8][6], matrix[8][7] = d7, v4, h3
    matrix[8][8], matrix[8][9] = -sum_rates(v8, h7, h4, d3), h8
    matrix[9][3], matrix[9][8], matrix[9][9] = d8, h4, -sum_rates(h8, d4)

    with localcontext() as context:
        context.prec = 60
        augmented = [row[:] + [value] for row, value in zip(matrix, right)]

        for column in range(10):
            pivot = max(
                range(column, 10),
                key=lambda row, current_column=column: abs(augmented[row][current_column]),
            )
            if augmented[pivot][column] == 0:
                raise np.linalg.LinAlgError('Steady-state matrix is singular')
            augmented[column], augmented[pivot] = augmented[pivot], augmented[column]

            for row in range(column + 1, 10):
                factor = augmented[row][column] / augmented[column][column]
                for j in range(column + 1, 11):
                    augmented[row][j] -= factor * augmented[column][j]
                augmented[row][column] = Decimal(0)

        coverages = [Decimal(0) for _ in range(10)]
        for row in range(9, -1, -1):
            remainder = augmented[row][10] - sum(
                augmented[row][j] * coverages[j] for j in range(row + 1, 10)
            )
            coverages[row] = remainder / augmented[row][row]

        if any(value < 0 for value in coverages):
            raise np.linalg.LinAlgError('Steady-state solution contains negative coverage')
        total = sum(coverages)
        if total <= 0:
            raise np.linalg.LinAlgError('Steady-state solution has a non-positive sum')
        return np.array([float(value / total) for value in coverages])


def integrate_step_rate(free_energy, eta, ph, reorganization, kbt, water_energy, reverse, base):
    if reorganization <= 0:
        raise ValueError('Reorganization energy must be positive')
    drive = free_energy + eta - np.log(10.0) * kbt * ph
    if base:
        drive += water_energy

    integral, _ = integrate.quad(
        step_rate_integrand,
        -np.inf,
        np.inf,
        args=(drive, reorganization, kbt, reverse, base),
        epsabs=1e-12,
        epsrel=1e-12,
        limit=1000,
    )
    return integral


def step_rate_integrand(x, drive, reorganization, kbt, reverse, base):
    drive_sign = -1.0 if reverse else 1.0
    x_sign = 1.0 if reverse else -1.0
    numerator = drive_sign * drive + x_sign * x + reorganization
    thermal_coordinate = -x / kbt if reverse and base else x / kbt
    exponent = -(numerator * numerator) / (4.0 * reorganization * kbt)
    return np.exp(exponent - np.logaddexp(0.0, thermal_coordinate))


def calculate_electrochemical_rates(values, kbt, eta, ph, water_energy, proton_activity, hydroxide_activity, prefactor):
    rates = {}
    for step in range(1, 9):
        family, number = ('V', step) if step <= 4 else ('H', step - 4)
        free_energy = values[f'G{family}{number}']
        reorganization = values[f'lambda{family}{number}']
        acid_forward = integrate_step_rate(free_energy, eta, ph, reorganization, kbt, water_energy, False, False)
        acid_reverse = integrate_step_rate(free_energy, eta, ph, reorganization, kbt, water_energy, True, False)
        base_forward = integrate_step_rate(free_energy, eta, ph, reorganization, kbt, water_energy, False, True)
        base_reverse = integrate_step_rate(free_energy, eta, ph, reorganization, kbt, water_energy, True, True)
        rates[f'{family}{number}'] = acid_forward * prefactor * proton_activity + base_forward * prefactor
        rates[f'{family}-{number}'] = acid_reverse * prefactor + base_reverse * prefactor * hydroxide_activity
    return rates


def calculate_nonideal_rates(values, delta_g0, kbt, sigma, prefactor):
    rates = {}
    free_energies = (
        [values[f'GA{i}'] for i in range(1, 5)]
        + [delta_g0 - values[f'GA{i}'] - values[f'GV{i}'] - values[f'GH{i}'] for i in range(1, 5)]
        + [delta_g0 - values['GA3'] - values['GV3']]
    )
    free_energies[8] -= free_energies[4]
    for index, free_energy in enumerate(free_energies):
        forward = prefactor * np.exp(-np.logaddexp(0.0, sigma * free_energy) / (sigma * kbt))
        reverse = prefactor * np.exp(-np.logaddexp(0.0, -sigma * free_energy) / (sigma * kbt))
        if index < 4:
            prefix, number = 'A', index + 1
            rates[f'{prefix}{number}'] = forward
            rates[f'{prefix}-{number}'] = reverse
        elif index < 8:
            prefix, number = 'D', index - 3
            rates[f'{prefix}{number}'] = forward
            rates[f'{prefix}-{number}'] = reverse
        else:
            rates['T_rate'] = forward
            rates['T_reverse_rate'] = reverse
    return rates


def calculate_case(row):
    values = {name: float(row[name]) for name in REQUIRED_COLUMNS}
    if not all(np.isfinite(value) for value in values.values()):
        raise ValueError('Required parameters must all be finite numbers')
    temperature, proton_activity, pressure, sigma = (
        values['T'], values['a_H'], values['p'], values['sigma']
    )
    if temperature <= 0 or proton_activity <= 0 or pressure <= 0 or sigma <= 0:
        raise ValueError('T, p, a_H, and sigma must be positive')

    k_b = float(row.get('kB', DEFAULT_KB))
    planck = float(row.get('h', DEFAULT_H))
    if not np.isfinite(k_b) or not np.isfinite(planck) or k_b <= 0 or planck <= 0:
        raise ValueError('kB and h must be finite and positive')

    kbt = k_b * temperature
    prefactor = kbt / planck
    kw = calculate_kw(temperature)
    hydroxide_activity = kw / proton_activity
    ph = -np.log10(proton_activity)
    water_energy = -kbt * np.log(kw)
    delta_g0 = kbt * (np.log(pressure) - 2.0 * np.log(proton_activity))
    result = dict(row.items())

    thermodynamics = calculate_nonideal_rates(values, delta_g0, kbt, sigma, prefactor)
    result.update({
        f'GD{i}': delta_g0 - values[f'GA{i}'] - values[f'GV{i}'] - values[f'GH{i}']
        for i in range(1, 5)
    })
    result['GT'] = delta_g0 - values['GA3'] - values['GV3'] - result['GD1']
    electrochemical_values = dict(values)
    electrochemical_values.update({
        key: value for key, value in values.items() if key.startswith(('GV', 'GH', 'lambdaV', 'lambdaH'))
    })
    result.update(thermodynamics)
    result.update(calculate_electrochemical_rates(
        electrochemical_values, kbt, values['eta'], ph, water_energy,
        proton_activity, hydroxide_activity, prefactor,
    ))

    ordered_rate_names = [
        *[f'A{i}' for i in range(1, 5)], *[f'A-{i}' for i in range(1, 5)],
        *[f'D{i}' for i in range(1, 5)], *[f'D-{i}' for i in range(1, 5)],
        *[f'V{i}' for i in range(1, 5)], *[f'V-{i}' for i in range(1, 5)],
        *[f'H{i}' for i in range(1, 5)], *[f'H-{i}' for i in range(1, 5)],
        'T_rate', 'T_reverse_rate',
    ]
    coverage = solve_coverages([result[name] for name in ordered_rate_names])
    result.update({f'x{i + 1}': coverage[i] for i in range(10)})
    net_rates = {
        'rD1': result['D1'] * coverage[3] - result['D-1'] * coverage[0],
        'rD2': result['D2'] * coverage[6] - result['D-2'] * coverage[1],
        'rD3': result['D3'] * coverage[8] - result['D-3'] * coverage[2],
        'rD4': result['D4'] * coverage[9] - result['D-4'] * coverage[3],
    }
    result.update(net_rates)
    result['rH2'] = sum(net_rates.values())
    return result


def run_batch(input_path, output_path):
    input_path = Path(input_path).resolve()
    output_path = Path(output_path).resolve()
    if input_path == output_path:
        raise ValueError('Input and output paths must be different')

    data = pd.read_csv(input_path, encoding='utf-8-sig')
    missing = [column for column in REQUIRED_COLUMNS if column not in data.columns]
    if missing:
        raise ValueError(f'Missing required CSV columns: {", ".join(missing)}')
    if data.empty:
        raise ValueError('Input CSV contains no parameter rows')
    if 'case_id' not in data.columns:
        data.insert(0, 'case_id', [f'case_{index + 1:06d}' for index in range(len(data))])

    outputs = []
    for index, row in data.iterrows():
        try:
            outputs.append(calculate_case(row))
        except Exception as error:
            raise ValueError(f'Case {row["case_id"]} (CSV row {index + 2}): {error}') from error

    output_path.parent.mkdir(parents=True, exist_ok=True)
    pd.DataFrame(outputs).to_csv(output_path, index=False, encoding='utf-8-sig')
    return output_path, len(outputs)


def main():
    parser = argparse.ArgumentParser(description='Batch HER/HOR rate and coverage calculator')
    parser.add_argument('--input', required=True, help='Input parameter CSV')
    parser.add_argument('--output', default='results.csv', help='Output results CSV')
    args = parser.parse_args()
    output_path, count = run_batch(args.input, args.output)
    print(f'Calculated {count} cases -> {output_path}')


if __name__ == '__main__':
    main()