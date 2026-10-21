function rH2_eta_curve(varargin)
%RH2_ETA_CURVE  计算并直接绘制 rH2 ~ eta 关系图
%   一次调用完成：生成 eta 扫描表 -> 逐点计算 -> 画图 -> 存 PNG/CSV。
%
%   rH2_eta_curve()
%   rH2_eta_curve('etaStep', 0.002)
%   rH2_eta_curve('etaStart', -0.25, 'etaStop', 0.25, 'etaStep', 0.001, ...
%                 'precision', 'vpa', 'outputDir', 'D:\somewhere')
%
%   默认区间 -0.25 V ~ 0.25 V，步长 0.001 V（501 个点）。
%
%   产出（默认写在 matlab 子目录）：
%     rH2_eta_input.csv   扫描参数表
%     rH2_eta_results.csv 计算结果（含全部 80 列）
%     rH2_eta_curve.png   rH2 ~ eta 曲线（线性纵轴）
%     rH2_eta_curve_log.png |rH2| ~ eta 曲线（对数纵轴）
%
%   注意：每个 eta 点需要 32 次高精度数值积分，点数直接决定耗时。
%   0.001 V 步长约 501 点；若只是想看趋势，用 0.002 或 0.005 会快得多。

    parser = inputParser;
    parser.addParameter('etaStart', -0.25, @(x) isnumeric(x) && isscalar(x));
    parser.addParameter('etaStop',   0.25, @(x) isnumeric(x) && isscalar(x));
    parser.addParameter('etaStep',   0.001, @(x) isnumeric(x) && isscalar(x));
    parser.addParameter('p',    1.0, @(x) isnumeric(x) && isscalar(x));
    parser.addParameter('aH',   1.0, @(x) isnumeric(x) && isscalar(x));
    parser.addParameter('precision', 'vpa', @(x) ischar(x) || isstring(x));
    parser.addParameter('outputDir', fileparts(mfilename('fullpath')), @(x) ischar(x) || isstring(x));
    parser.addParameter('makePlot', true, @(x) islogical(x) && isscalar(x));
    parser.parse(varargin{:});
    opt = parser.Results;

    outputDir = char(opt.outputDir);
    if ~isfolder(outputDir)
        mkdir(outputDir);
    end

    inputPath   = fullfile(outputDir, 'rH2_eta_input.csv');
    resultsPath = fullfile(outputDir, 'rH2_eta_results.csv');
    linearPath  = fullfile(outputDir, 'rH2_eta_curve.png');
    logPath     = fullfile(outputDir, 'rH2_eta_curve_log.png');

    % ---- 1) 生成扫描表 ----
    scan = build_scan(opt.etaStart, opt.etaStop, opt.etaStep);
    scan.p   = repmat(opt.p,  height(scan), 1);
    scan.a_H = repmat(opt.aH, height(scan), 1);
    write_csv_utf8bom([scan.Properties.VariableNames; table2cell(scan)], inputPath);

    pointCount = height(scan);
    fprintf('eta 区间 [%g, %g] V，步长 %g V，共 %d 个点\n', ...
            opt.etaStart, opt.etaStop, opt.etaStep, pointCount);
    fprintf('开始计算（每个点 32 次积分，请耐心等待）...\n');

    % ---- 2) 逐点计算 ----
    tStart = tic;
    [~, caseCount] = run_batch(inputPath, resultsPath, struct('precision', opt.precision));
    elapsed = toc(tStart);
    fprintf('计算完成：%d 个点，耗时 %.1f 秒（%.2f 秒/点）\n', ...
            caseCount, elapsed, elapsed / max(caseCount, 1));

    % ---- 3) 出图 ----
    % 结果 CSV 里有 'A-1' 这类非法标识符列名，必须用 preserve 读取
    results = readtable(resultsPath, 'Encoding', 'UTF-8', 'VariableNamingRule', 'preserve');
    [~, order] = sort(results.eta);
    results = results(order, :);
    eta  = results.eta;
    rate = results.rH2;

    if opt.makePlot
        draw_linear(eta, rate, linearPath);
        draw_log(eta, rate, logPath);
    end

    % ---- 4) 过零与极值摘要 ----
    crossing = find_zero_crossing(eta, rate);
    [minAbs, minIdx] = min(abs(rate));

    fprintf('\n----- 曲线特征 -----\n');
    fprintf('净速率过零点 eta        = %.6f V\n', crossing);
    fprintf('|rH2| 最小采样点 eta     = %.6f V   (|rH2| = %.6e)\n', eta(minIdx), minAbs);
    fprintf('rH2 最大值             = %.6e  (eta = %.6f V)\n', max(rate), eta(find(rate == max(rate), 1)));
    fprintf('rH2 最小值             = %.6e  (eta = %.6f V)\n', min(rate), eta(find(rate == min(rate), 1)));
    fprintf('\n产出文件：\n  %s\n  %s\n  %s\n  %s\n', ...
            inputPath, resultsPath, linearPath, logPath);
end


% ---------------------------------------------------------------- 绘图
function draw_linear(eta, rate, path)
    fig = figure('Color', 'w', 'Position', [80 80 960 560], 'Visible', 'off');
    ax = axes(fig); %#ok<LAXES>
    plot(ax, eta, rate, '-', 'Color', [0.031 0.498 0.439], 'LineWidth', 2.0);
    hold(ax, 'on');
    plot(ax, xlim(ax), [0 0], '-', 'Color', [0.45 0.45 0.45], 'LineWidth', 0.9);
    plot(ax, [0 0], ylim(ax), ':', 'Color', [0.55 0.55 0.55], 'LineWidth', 0.9);
    hold(ax, 'off');

    xlabel(ax, 'Overpotential, \eta (V)');
    ylabel(ax, 'Net rate, r_{H_2} (model units)');
    title(ax, 'HER/HOR net rate vs overpotential');
    grid(ax, 'on');
    ax.GridColor = [0.682 0.725 0.710];
    ax.GridAlpha = 0.35;
    box(ax, 'off');

    exportgraphics(fig, path, 'Resolution', 240);
    close(fig);
end

function draw_log(eta, rate, path)
    magnitude = abs(rate);

    fig = figure('Color', 'w', 'Position', [80 80 960 560], 'Visible', 'off');
    ax = axes(fig); %#ok<LAXES>
    semilogy(ax, eta, magnitude, '-', 'Color', [0.031 0.498 0.439], 'LineWidth', 2.0);
    hold(ax, 'on');
    plot(ax, [0 0], ylim(ax), ':', 'Color', [0.55 0.55 0.55], 'LineWidth', 0.9);
    hold(ax, 'off');

    xlabel(ax, 'Overpotential, \eta (V)');
    ylabel(ax, '|r_{H_2}| (model units)');
    title(ax, 'HER/HOR net-rate magnitude vs overpotential');
    grid(ax, 'on');
    ax.GridColor = [0.682 0.725 0.710];
    ax.GridAlpha = 0.35;
    box(ax, 'off');

    exportgraphics(fig, path, 'Resolution', 240);
    close(fig);
end


% ---------------------------------------------------------------- 过零
function crossing = find_zero_crossing(eta, rate)
    idx = find(rate(1:end-1) .* rate(2:end) <= 0);
    if isempty(idx)
        [~, k] = min(abs(rate));
        crossing = eta(k);
        return;
    end
    [~, nearest] = min(abs(eta(idx)));
    i = idx(nearest);
    r1 = rate(i);
    r2 = rate(i + 1);
    if r1 == r2
        crossing = eta(i);
        return;
    end
    crossing = eta(i) + (-r1 / (r2 - r1)) * (eta(i + 1) - eta(i));
end
