function near_equilibrium_sweep(varargin)
%NEAR_EQUILIBRIUM_SWEEP  近平衡区净速率过零扫描 + 出图
%   对应 Python near_equilibrium_sweep.py。
%
%   near_equilibrium_sweep()
%   near_equilibrium_sweep('p', 0.1, 'aH', 1.0, 'etaStep', 0.002)
%
%   写出四个文件（与 Python 同名）：
%     near_equilibrium_input.csv     扫描参数表
%     near_equilibrium_results.csv   计算结果（rH2 保留符号）
%     rH2_eta_Ushape.png             |rH2| ~ eta（对数纵轴）
%     rH2_eta_signed.png             有符号 rH2 ~ eta

    parser = inputParser;
    parser.addParameter('etaStart', -0.25, @(x) isnumeric(x) && isscalar(x));
    parser.addParameter('etaStop',   0.25, @(x) isnumeric(x) && isscalar(x));
    parser.addParameter('etaStep',   0.002, @(x) isnumeric(x) && isscalar(x));
    parser.addParameter('p',    0.1, @(x) isnumeric(x) && isscalar(x));
    parser.addParameter('aH',   1.0, @(x) isnumeric(x) && isscalar(x));
    parser.addParameter('outputDir', fileparts(mfilename('fullpath')), @(x) ischar(x) || isstring(x));
    parser.addParameter('precision', 'vpa', @(x) ischar(x) || isstring(x));
    parser.parse(varargin{:});
    opt = parser.Results;

    outputDir = char(opt.outputDir);
    if ~isfolder(outputDir)
        mkdir(outputDir);
    end

    inputPath    = fullfile(outputDir, 'near_equilibrium_input.csv');
    resultsPath  = fullfile(outputDir, 'near_equilibrium_results.csv');
    magnitudePath = fullfile(outputDir, 'rH2_eta_Ushape.png');
    signedPath    = fullfile(outputDir, 'rH2_eta_signed.png');

    scan = build_scan(opt.etaStart, opt.etaStop, opt.etaStep);
    scan.p   = repmat(opt.p,  height(scan), 1);
    scan.a_H = repmat(opt.aH, height(scan), 1);
    write_csv_utf8bom([scan.Properties.VariableNames; table2cell(scan)], inputPath);

    [~, caseCount] = run_batch(inputPath, resultsPath, struct('precision', opt.precision));

    [zeroCrossing, minimumEta, minimumRate] = save_plots(resultsPath, magnitudePath, signedPath);

    fprintf('Cases: %d\n', caseCount);
    fprintf('Net-rate zero (linear interpolation): eta = %.6f V\n', zeroCrossing);
    fprintf('Minimum sampled |rH2|: eta = %.6f V, |rH2| = %.6e\n', minimumEta, minimumRate);
    fprintf('Input: %s\n', inputPath);
    fprintf('Results: %s\n', resultsPath);
    fprintf('Magnitude plot: %s\n', magnitudePath);
    fprintf('Signed plot: %s\n', signedPath);
end


function [zeroCrossing, minimumEta, minimumRate] = save_plots(resultsPath, magnitudePath, signedPath)
    results = readtable(resultsPath, 'Encoding', 'UTF-8');
    [~, order] = sort(results.eta);
    results = results(order, :);

    eta        = results.eta;
    signedRate = results.rH2;

    zeroCrossing = find_zero_crossing(eta, signedRate);
    magnitude    = abs(signedRate);
    [minimumRate, minimumIndex] = min(magnitude);
    minimumEta   = eta(minimumIndex);

    % ---- 图 1：|rH2| 对数纵轴 ----
    fig = figure('Color', 'w', 'Position', [80 80 880 520], 'Visible', 'off');
    ax = axes(fig); %#ok<LAXES>
    semilogy(ax, eta, magnitude, '-o', ...
        'Color', [0.031 0.498 0.439], 'LineWidth', 2.0, ...
        'MarkerSize', 3.0, 'MarkerFaceColor', [0.949 0.647 0.255], ...
        'MarkerEdgeColor', 'none');
    hold(ax, 'on');
    plot(ax, [zeroCrossing zeroCrossing], ylim(ax), '--', ...
        'Color', [0.741 0.310 0.208], 'LineWidth', 1.2);
    plot(ax, [0 0], ylim(ax), ':', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.0);
    plot(ax, eta(minimumIndex), magnitude(minimumIndex), 'o', ...
        'MarkerFaceColor', [0.741 0.310 0.208], 'MarkerEdgeColor', 'none', 'MarkerSize', 7);
    hold(ax, 'off');

    xlabel(ax, 'Overpotential, \eta (V)');
    ylabel(ax, 'Net-rate magnitude, |r_{H_2}| (model units)');
    title(ax, sprintf('Near-equilibrium rate magnitude (p = %g)', results.p(1)));
    grid(ax, 'on');
    ax.GridColor = [0.682 0.725 0.710];
    ax.GridAlpha = 0.4;
    box(ax, 'off');
    legend(ax, {sprintf('Net-rate zero: %.4f V', zeroCrossing), '0 V reference'}, ...
        'Location', 'best', 'Box', 'off');

    exportgraphics(fig, magnitudePath, 'Resolution', 220);
    close(fig);

    % ---- 图 2：有符号 rH2 ----
    fig = figure('Color', 'w', 'Position', [80 80 880 520], 'Visible', 'off');
    ax = axes(fig); %#ok<LAXES>
    plot(ax, eta, signedRate, '-', 'Color', [0.031 0.498 0.439], 'LineWidth', 2.0);
    hold(ax, 'on');
    plot(ax, xlim(ax), [0 0], '-', 'Color', [0.4 0.4 0.4], 'LineWidth', 0.9);
    plot(ax, [zeroCrossing zeroCrossing], ylim(ax), '--', ...
        'Color', [0.741 0.310 0.208], 'LineWidth', 1.2);
    plot(ax, [0 0], ylim(ax), ':', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.0);
    hold(ax, 'off');

    xlabel(ax, 'Overpotential, \eta (V)');
    ylabel(ax, 'Signed net rate, r_{H_2} (model units)');
    title(ax, 'Signed HER/HOR net rate near equilibrium');
    grid(ax, 'on');
    ax.GridColor = [0.682 0.725 0.710];
    ax.GridAlpha = 0.4;
    box(ax, 'off');
    legend(ax, {sprintf('Net-rate zero: %.4f V', zeroCrossing), '0 V reference'}, ...
        'Location', 'best', 'Box', 'off');

    exportgraphics(fig, signedPath, 'Resolution', 220);
    close(fig);
end


function crossing = find_zero_crossing(eta, signedRate)
%FIND_ZERO_CROSSING  线性插值找净速率过零点
%   对应 Python near_equilibrium_sweep.py 中的 find_zero_crossing。
    idx = find(signedRate(1:end-1) .* signedRate(2:end) <= 0);
    if isempty(idx)
        [~, k] = min(abs(signedRate));
        crossing = eta(k);
        return;
    end

    % 取离 0 V 最近的那个过零区间
    [~, nearest] = min(abs(eta(idx)));
    i = idx(nearest);

    firstRate  = signedRate(i);
    secondRate = signedRate(i + 1);
    if firstRate == secondRate
        crossing = eta(i);
        return;
    end
    fraction = -firstRate / (secondRate - firstRate);
    crossing = eta(i) + fraction * (eta(i + 1) - eta(i));
end
