import argparse
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from calculator import run_batch


BASELINE = {
    'GA1': -0.25,
    'GA2': -0.20,
    'GA3': -0.20,
    'GA4': -0.20,
    'GV1': 0.10,
    'GV2': 0.10,
    'GV3': 0.10,
    'GV4': 0.10,
    'GH1': 0.30,
    'GH2': 0.30,
    'GH3': 0.30,
    'GH4': 0.30,
    'lambdaV1': 0.50,
    'lambdaV2': 0.50,
    'lambdaV3': 0.50,
    'lambdaV4': 0.50,
    'lambdaH1': 0.20,
    'lambdaH2': 0.20,
    'lambdaH3': 0.20,
    'lambdaH4': 0.20,
    'T': 298.15,
    'p': 1.0,
    'a_H': 1.0,
    'sigma': 0.5,
}


def build_scan(start, stop, step):
    if step <= 0 or stop < start:
        raise ValueError('Require step > 0 and eta-stop >= eta-start')
    intervals = (stop - start) / step
    count = round(intervals)
    if not np.isclose(intervals, count, rtol=1e-10, atol=1e-10):
        raise ValueError('(eta-stop - eta-start) must be divisible by eta-step')

    etas = np.round(start + step * np.arange(count + 1), 12)
    cases = pd.DataFrame([BASELINE.copy() for _ in etas])
    cases.insert(0, 'case_id', [f'eta_{index + 1:04d}' for index in range(len(etas))])
    cases['eta'] = etas
    return cases


def save_plot(results_path, plot_path):
    results = pd.read_csv(results_path)
    results = results.sort_values('eta')

    figure, axis = plt.subplots(figsize=(9.2, 5.4), constrained_layout=True)
    axis.plot(
        results['eta'],
        results['rH2'],
        color='#087f70',
        linewidth=2.0,
        marker='o',
        markersize=2.8,
        markerfacecolor='#f2a541',
        markeredgewidth=0,
    )
    axis.axhline(0.0, color='#555555', linewidth=0.8, alpha=0.7)
    axis.set_xlabel(r'Overpotential, $\eta$ (V)')
    axis.set_ylabel(r'Total rate, $r_{H_2}$ (model units)')
    axis.set_title('HER/HOR baseline eta scan')
    axis.grid(True, which='major', color='#aeb9b5', linewidth=0.6, alpha=0.38)
    axis.ticklabel_format(axis='y', style='sci', scilimits=(0, 0), useMathText=True)
    axis.spines[['top', 'right']].set_visible(False)
    figure.savefig(plot_path, dpi=220, facecolor='white')
    plt.close(figure)


def main():
    default_dir = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description='Generate a baseline HER/HOR eta sweep and plot')
    parser.add_argument('--eta-start', type=float, default=-0.25)
    parser.add_argument('--eta-stop', type=float, default=0.305)
    parser.add_argument('--eta-step', type=float, default=0.005)
    parser.add_argument('--output-dir', type=Path, default=default_dir)
    args = parser.parse_args()

    output_dir = args.output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    input_path = output_dir / 'baseline_eta_scan.csv'
    results_path = output_dir / 'baseline_eta_results.csv'
    plot_path = output_dir / 'rH2_eta.png'

    scan = build_scan(args.eta_start, args.eta_stop, args.eta_step)
    scan.to_csv(input_path, index=False, encoding='utf-8-sig')
    _, case_count = run_batch(input_path, results_path)
    save_plot(results_path, plot_path)

    print(f'Cases: {case_count}')
    print(f'Input: {input_path}')
    print(f'Results: {results_path}')
    print(f'Plot: {plot_path}')


if __name__ == '__main__':
    main()