function cases = build_scan(startValue, stopValue, stepValue)
%BUILD_SCAN  生成过电位扫描的参数表
%   对应 Python eta_sweep.py 中的 build_scan。
%
%   返回 table，列顺序：case_id, <BASELINE 各列...>, eta
%   （eta 在最后一列，与 Python 里 cases['eta'] = etas 的追加顺序一致）

    if stepValue <= 0 || stopValue < startValue
        error('build_scan:badRange', 'Require step > 0 and eta-stop >= eta-start');
    end

    intervals = (stopValue - startValue) / stepValue;
    count = round(intervals);
    % 对应 np.isclose(intervals, count, rtol=1e-10, atol=1e-10)
    if abs(intervals - count) > (1e-10 + 1e-10 * abs(count))
        error('build_scan:notDivisible', '(eta-stop - eta-start) must be divisible by eta-step');
    end

    % 对应 np.round(..., 12)：保留 12 位小数，压掉浮点累加误差
    etas = round((startValue + stepValue * (0:count)) * 1e12) / 1e12;
    n = numel(etas);

    baseline = baseline_parameters();
    cases = table();
    cases.case_id = arrayfun(@(i) sprintf('eta_%04d', i), 1:n, 'UniformOutput', false)';

    fields = fieldnames(baseline);
    for i = 1:numel(fields)
        cases.(fields{i}) = repmat(baseline.(fields{i}), n, 1);
    end

    cases.eta = etas(:);
end
