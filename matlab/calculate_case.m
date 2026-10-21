function result = calculate_case(row, options)
%CALCULATE_CASE  计算单个参数情形
%   对应 Python calculator.py 中的 calculate_case。
%
%   row     : 结构体，字段为输入 CSV 的一行（含 case_id 及全部参数列）
%   options : 可选，struct('precision','vpa') 或 struct('precision','double')
%
%   返回 result：以输入列开头，随后依次追加
%     GD1..GD4, GT,
%     A1,A-1,A2,A-2,...,D4,D-4, T_rate, T_reverse_rate,
%     V1,V-1,...,H4,H-4,
%     x1..x10,
%     rD1..rD4, rH2
%   （字段顺序与 Python 版输出 CSV 的列顺序一致）

    if nargin < 2 || isempty(options)
        options = struct();
    end
    if ~isfield(options, 'precision')
        options.precision = 'vpa';
    end

    names  = required_columns();
    values = struct();
    for i = 1:numel(names)
        name = names{i};
        if ~isfield(row, name)
            error('calculate_case:missingField', 'Missing required parameter: %s', name);
        end
        values.(name) = to_double(row.(name));
        if ~isfinite(values.(name))
            error('calculate_case:nonFinite', 'Required parameters must all be finite numbers');
        end
    end

    temperature     = values.T;
    proton_activity = values.a_H;
    pressure        = values.p;
    sigma           = values.sigma;
    if temperature <= 0 || proton_activity <= 0 || pressure <= 0 || sigma <= 0
        error('calculate_case:badRange', 'T, p, a_H, and sigma must be positive');
    end

    constants = default_constants();
    k_b    = get_optional(row, 'kB', constants.kB);
    planck = get_optional(row, 'h',  constants.h);
    if ~isfinite(k_b) || ~isfinite(planck) || k_b <= 0 || planck <= 0
        error('calculate_case:badConstants', 'kB and h must be finite and positive');
    end

    kbt       = k_b * temperature;
    prefactor = kbt / planck;
    kw        = calculate_kw(temperature);
    hydroxide_activity = kw / proton_activity;
    ph           = -log10(proton_activity);
    water_energy = -kbt * log(kw);
    delta_g0     = kbt * (log(pressure) - 2.0 * log(proton_activity));

    % 保留全部输入列（含 case_id），字段顺序即输入 CSV 的列顺序
    result = row;

    % --- GD1..GD4, GT ---
    GD = zeros(1, 4);
    for i = 1:4
        GD(i) = delta_g0 - values.(sprintf('GA%d', i)) ...
                          - values.(sprintf('GV%d', i)) ...
                          - values.(sprintf('GH%d', i));
        result.(sprintf('GD%d', i)) = GD(i);
    end
    result.GT = delta_g0 - values.GA3 - values.GV3 - GD(1);

    % --- 热力学速率（A/D 交错顺序写入，与 Python 的 dict 插入顺序一致）---
    spec = rate_field_order();
    thermodynamics = calculate_nonideal_rates(values, delta_g0, kbt, sigma, prefactor);
    for i = 1:numel(spec.thermoOutput)
        f = spec.thermoOutput{i};
        result.(f) = thermodynamics.(f);
    end

    % --- 电化学速率（V/H 交错顺序写入）---
    electrochemistry = calculate_electrochemical_rates(values, kbt, values.eta, ph, ...
        water_energy, proton_activity, hydroxide_activity, prefactor);
    for i = 1:numel(spec.electroOutput)
        f = spec.electroOutput{i};
        result.(f) = electrochemistry.(f);
    end

    % --- 稳态覆盖度 ---
    params = zeros(1, numel(spec.grouped));
    for i = 1:numel(spec.grouped)
        params(i) = result.(spec.grouped{i});
    end
    coverage = solve_coverages(params, options.precision);

    for i = 1:10
        result.(sprintf('x%d', i)) = coverage(i);
    end

    % --- 净速率 ---
    rD = zeros(1, 4);
    rD(1) = result.D1 * coverage(4)  - result.Dm1 * coverage(1);
    rD(2) = result.D2 * coverage(7)  - result.Dm2 * coverage(2);
    rD(3) = result.D3 * coverage(9)  - result.Dm3 * coverage(3);
    rD(4) = result.D4 * coverage(10) - result.Dm4 * coverage(4);
    for i = 1:4
        result.(sprintf('rD%d', i)) = rD(i);
    end
    result.rH2 = sum(rD);
end


% ---------------------------------------------------------------- 本地辅助
function v = to_double(x)
    if isnumeric(x)
        v = double(x);
    elseif ischar(x) || isstring(x)
        v = str2double(x);
    elseif iscell(x) && isscalar(x)
        v = to_double(x{1});
    else
        error('calculate_case:badType', 'Cannot convert value to double');
    end
end

function v = get_optional(row, name, fallback)
    % 注意：与 Python 的 row.get(name, default) 语义一致 ——
    % 只要该列存在就用它的值（哪怕是 NaN），只有列不存在时才用默认值。
    if isfield(row, name)
        v = to_double(row.(name));
    else
        v = fallback;
    end
end
