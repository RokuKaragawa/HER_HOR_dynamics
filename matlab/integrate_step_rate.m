function integral_value = integrate_step_rate(free_energy, eta, ph, reorganization, kbt, water_energy, reverse, base)
%INTEGRATE_STEP_RATE  对单步速率做全实轴数值积分
%   对应 Python calculator.py 中的 integrate_step_rate（其中调用 scipy.integrate.quad）。
%
%   算法选择说明：
%     scipy.integrate.quad 是 QUADPACK 的自适应 Gauss–Kronrod 求积，
%     MATLAB 里与之同源的函数是 quadgk（不是 integral）。
%     所以这里用 quadgk，并把 Python 侧设定的 epsabs=1e-12 / epsrel=1e-12 / limit=1000
%     一一对应到 AbsTol / RelTol / MaxIntervalCount，以取得最接近的数值结果。

    if reorganization <= 0
        error('integrate_step_rate:badReorganization', ...
              'Reorganization energy must be positive');
    end

    drive = free_energy + eta - log(10.0) * kbt * ph;
    if base
        drive = drive + water_energy;
    end

    integrand = @(x) step_rate_integrand(x, drive, reorganization, kbt, reverse, base);

    integral_value = quadgk(integrand, -Inf, Inf, ...
        'AbsTol', 1e-12, ...
        'RelTol', 1e-12, ...
        'MaxIntervalCount', 1000);
end
