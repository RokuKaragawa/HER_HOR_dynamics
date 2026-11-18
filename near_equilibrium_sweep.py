import argparse
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from calculator import run_batch
from eta_sweep import build_scan


def find_zero_crossing(eta, signed_rate):
    crossing_indices = np.flatnonzero(signed_rate[:-1] * signed_rate[1:] <= 0)
    if len(crossing_indices) == 0:
        return float(eta[np.argmin(np.abs(signed_rate))])

    index = crossing_indices[np.argmin(np.abs(eta[crossing_indices]))]
    first_rate = signed_rate[index]
    second_rate = signed_rate[index + 1]
    if first_rate == second_rate:
        return float(eta[index])
    fraction = -first_rate / (second_rate - first_rate)
    return float(eta[index] + fraction * (eta[index + 1] - eta[index]))


def save_plots(results_path, magnitude_plot_path, signed_plot_path):
    results = pd.read_csv(results_path).sort_values('eta')
    eta = results['eta'].to_numpy(float)
    signed_rate = results['rH2'].to_numpy(float)
    zero_crossing = find_zero_crossing(eta, signed_rate)
    magnitude = np.abs(signed_rate)
    minimum_index = int(np.argmin(magnitude))

    figure, axis = plt.subplots(figsize=(8.8, 5.2), constrained_layout=True)
    axis.semilogy(
        eta,
        magnitude,
        color='#087f70',
        linewidth=2.0,
        marker='o',
        markersize=3.0,
        markerfacecolor='#f2a541',
        markeredgewidth=0,
    )
    axis.axvline(zero_crossing, color='#bd4f35', linestyle='--', linewidth=1.2,
                 label=f'Net-rate zero: {zero_crossing:.4f} V')
    axis.axvline(0.0, color='#666666', linestyle=':', linewidth=1.0, label='0 V reference')
    axis.scatter([eta[minimum_index]], [magnitude[minimum_index]], color='#bd4f35', zorder=4)
    axis.set_xlabel(r'Overpotential, $\eta$ (V)')
    axis.set_ylabel(r'Net-rate magnitude, $|r_{H_2}|$ (model units)')
    axis.set_title(f'Near-equilibrium rate magnitude (p = {results["p"].iloc[0]:g})')
    axis.grid(True, which='major', color='#aeb9b5', linewidth=0.6, alpha=0.4)
    axis.spines[['top', 'right']].set_visible(False)
    axis.legend(frameon=False, loc='best')
    figure.savefig(magnitude_plot_path, dpi=220, facecolor='white')
    plt.close(figure)

    figure, axis = plt.subplots(figsize=(8.8, 5.2), constrained_layout=True)
    axis.plot(eta, signed_rate, color='#087f70', linewidth=2.0)
    axis.axhline(0.0, color='#666666', linewidth=0.9)
    axis.axvline(zero_crossing, color='#bd4f35', linestyle='--', linewidth=1.2,
                 label=f'Net-rate zero: {zero_crossing:.4f} V')
    axis.axvline(0.0, color='#666666', linestyle=':', linewidth=1.0, label='0 V reference')
    axis.set_xlabel(r'Overpotential, $\eta$ (V)')
    axis.set_ylabel(r'Signed net rate, $r_{H_2}$ (model units)')
    axis.set_title('Signed HER/HOR net rate near equilibrium')
    axis.grid(True, color='#aeb9b5', linewidth=0.6, alpha=0.4)
    axis.spines[['top', 'right']].set_visible(False)
    axis.legend(frameon=False, loc='best')
    figure.savefig(signed_plot_path, dpi=220, facecolor='white')
    plt.close(figure)

    return zero_crossing, eta[minimum_index], magnitude[minimum_index]


def main():
    default_dir = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description='Scan the HER/HOR net-rate zero near equilibrium')
    parser.add_argument('--eta-start', type=float, default=-0.25)
    parser.add_argument('--eta-stop', type=float, default=0.25)
    parser.add_argument('--eta-step', type=float, default=0.002)
    parser.add_argument('--p', type=float, default=0.1, help='Hydrogen pressure in the model input')
    parser.add_argument('--a-h', type=float, default=1.0, help='Proton activity')
    parser.add_argument('--output-dir', type=Path, default=default_dir)
    args = parser.parse_args()

    output_dir = args.output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    input_path = output_dir / 'near_equilibrium_input.csv'
    results_path = output_dir / 'near_equilibrium_results.csv'
    magnitude_plot_path = output_dir / 'rH2_eta_Ushape.png'
    signed_plot_path = output_dir / 'rH2_eta_signed.png'

    scan = build_scan(args.eta_start, args.eta_stop, args.eta_step)
    scan['p'] = args.p
    scan['a_H'] = args.a_h
    scan.to_csv(input_path, index=False, encoding='utf-8-sig')
    _, case_count = run_batch(input_path, results_path)
    zero_crossing, minimum_eta, minimum_rate = save_plots(
        results_path, magnitude_plot_path, signed_plot_path
    )

    print(f'Cases: {case_count}')
    print(f'Net-rate zero (linear interpolation): eta = {zero_crossing:.6f} V')
    print(f'Minimum sampled |rH2|: eta = {minimum_eta:.6f} V, |rH2| = {minimum_rate:.6e}')
    print(f'Input: {input_path}')
    print(f'Results: {results_path}')
    print(f'Magnitude plot: {magnitude_plot_path}')
    print(f'Signed plot: {signed_plot_path}')


if __name__ == '__main__':
    main()