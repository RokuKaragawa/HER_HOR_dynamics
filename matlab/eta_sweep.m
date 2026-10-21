function eta_sweep(varargin)
%ETA_SWEEP  基线过电位扫描 + 出图
%   对应 Python eta_sweep.py。
%
%   eta_sweep()
%   eta_sweep('etaStart', -0.25, 'etaStop', 0.305, 'etaStep', 0.005)
%   eta_sweep('outputDir', 'D:\somewhere', 'precision', 'double')
%
%   写出三个文件（与 Python 同名，便于逐值对比）：
%     baseline_eta_scan.csv     扫描参数表
%     baseline_eta_results.csv  计算结果
%     rH2_eta.png               rH2 ~ eta 曲线

    parser = inputParser;
    parser.addParameter('etaStart', -0.25, @(x) isnumeric(x) && isscalar(x));
    parser.addParameter('etaStop',   0.305, @(x) isnumeric(x) && isscalar(x));
    parser.addParameter('etaStep',   0.005, @(x) isnumeric(x) && isscalar(x));
    parser.addParameter('outputDir', fileparts(mfilename('fullpath')), @(x) ischar(x) || isstring(x));
    parser.addParameter('precision', 'vpa', @(x) ischar(x) || isstring(x));
    parser.parse(varargin{:});
    opt = parser.Results;

    outputDir = char(opt.outputDir);
    if ~isfolder(outputDir)
        mkdir(outputDir);
    end

    inputPath   = fullfile(outputDir, 'baseline_eta_scan.csv');
    resultsPath = fullfile(outputDir, 'baseline_eta_results.csv');
    plotPath    = fullfile(outputDir, 'rH2_eta.png');

    scan = build_scan(opt.etaStart, opt.etaStop, opt.etaStep);
    write_csv_utf8bom([scan.Properties.VariableNames; table2cell(scan)], inputPath);

    [~, caseCount] = run_batch(inputPath, resultsPath, struct('precision', opt.precision));

    save_eta_plot(resultsPath, plotPath);

    fprintf('Cases: %d\n', caseCount);
    fprintf('Input: %s\n', inputPath);
    fprintf('Results: %s\n', resultsPath);
    fprintf('Plot: %s\n', plotPath);
end


function save_eta_plot(resultsPath, plotPath)
    results = readtable(resultsPath, 'Encoding', 'UTF-8');
    [~, order] = sort(results.eta);
    results = results(order, :);

    fig = figure('Color', 'w', 'Position', [80 80 920 540], 'Visible', 'off');
    ax = axes(fig); %#ok<LAXES>
    plot(ax, results.eta, results.rH2, '-o', ...
        'Color', [0.031 0.498 0.439], 'LineWidth', 2.0, ...
        'MarkerSize', 2.8, 'MarkerFaceColor', [0.949 0.647 0.255], ...
        'MarkerEdgeColor', 'none');
    hold(ax, 'on');
    plot(ax, xlim(ax), [0 0], '-', 'Color', [0.333 0.333 0.333], 'LineWidth', 0.8);
    hold(ax, 'off');

    xlabel(ax, 'Overpotential, \eta (V)');
    ylabel(ax, 'Total rate, r_{H_2} (model units)');
    title(ax, 'HER/HOR baseline eta scan');
    grid(ax, 'on');
    ax.GridColor = [0.682 0.725 0.710];
    ax.GridAlpha = 0.38;
    ax.YAxis.Exponent = 0;          % 强制科学计数法显示
    box(ax, 'off');

    exportgraphics(fig, plotPath, 'Resolution', 220);
    close(fig);
end
