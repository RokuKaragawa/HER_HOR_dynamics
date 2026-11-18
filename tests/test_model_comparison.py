import math
import tempfile
import unittest
from pathlib import Path

import numpy as np
import pandas as pd

from calculator import calculate_case, calculate_single_site_case, solve_single_site_coverages
from comparison_sweep import run_comparison


ROOT = Path(__file__).resolve().parents[1]


class SingleSiteModelTests(unittest.TestCase):
    def test_coverages_satisfy_steady_state_and_normalization(self):
        rates = [2.4, 1.3, 5.2, 0.8, 3.7, 1.1, 4.6, 0.7]
        vacant, water, hydrogen, hydrogen_gas = solve_single_site_coverages(rates)
        a_forward, a_reverse, v_forward, v_reverse, h_forward, h_reverse, d_forward, d_reverse = rates

        residuals = [
            a_forward * vacant - (a_reverse + v_forward) * water + v_reverse * hydrogen,
            v_forward * water - (v_reverse + h_forward) * hydrogen + h_reverse * hydrogen_gas,
            d_reverse * vacant + h_forward * hydrogen - (h_reverse + d_forward) * hydrogen_gas,
        ]
        self.assertAlmostEqual(float(np.sum([vacant, water, hydrogen, hydrogen_gas])), 1.0)
        self.assertTrue(np.all(np.asarray([vacant, water, hydrogen, hydrogen_gas]) >= 0))
        for residual in residuals:
            self.assertAlmostEqual(float(residual), 0.0, delta=1e-12)

    def test_single_site_case_returns_net_desorption_rate(self):
        row = pd.read_csv(ROOT / 'input_template.csv').iloc[0]
        result = calculate_single_site_case(row)
        expected_rate = (
            result['D_simple'] * result['theta_H2']
            - result['D_reverse_simple'] * result['theta_vacant']
        )

        self.assertTrue(math.isfinite(result['rH2']))
        self.assertAlmostEqual(result['rH2'], expected_rate, delta=1e-25)
        self.assertAlmostEqual(
            sum(result[name] for name in ('theta_vacant', 'theta_H2O', 'theta_H', 'theta_H2')),
            1.0,
        )


class ComparisonSweepTests(unittest.TestCase):
    def test_sweep_writes_both_models_at_each_eta(self):
        source = pd.read_csv(ROOT / 'input_template.csv')
        with tempfile.TemporaryDirectory() as directory:
            input_path = Path(directory) / 'input.csv'
            output_path = Path(directory) / 'comparison.csv'
            source.to_csv(input_path, index=False)

            written_path, row_count = run_comparison(
                input_path, output_path, -0.25, -0.24, 0.01
            )
            result = pd.read_csv(written_path)

        self.assertEqual(row_count, 2)
        self.assertEqual(len(result), 2)
        self.assertEqual(result['eta'].tolist(), [-0.25, -0.24])
        self.assertTrue(result['rH2_single_site'].map(math.isfinite).all())
        self.assertTrue(result['rH2_dual_site'].map(math.isfinite).all())

    def test_complex_model_example_result_is_unchanged(self):
        row = pd.read_csv(ROOT / 'input_template.csv').iloc[0]
        result = calculate_case(row)
        self.assertTrue(
            math.isclose(result['rH2'], 2.561774620934519e-13, rel_tol=1e-12)
        )


if __name__ == '__main__':
    unittest.main()
