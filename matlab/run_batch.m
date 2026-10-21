function [outputPath, count] = run_batch(inputPath, outputPath, options)
%RUN_BATCH  批量计算：读参数 CSV，逐行计算，写出结果 CSV
%   对应 Python calculator.py 中的 run_batch。
%
%   [outputPath, count] = run_batch(inputPath, outputPath)
%   [...] = run_batch(inputPath, outputPath, struct('precision','double'))
%
%   输出 CSV 的列顺序与 Python 版完全一致：
%     输入列（保持原顺序） + GD1..GT + A/D/T + V/H + x1..x10 + rD1..rD4 + rH2

    if nargin < 3 || isempty(options)
        options = struct();
    end
    if ~isfield(options, 'precision')
        options.precision = 'vpa';
    end

    inputPath  = canonical_path(inputPath);
    outputPath = canonical_path(outputPath);

    if strcmpi(inputPath, outputPath)
        error('run_batch:samePath', 'Input and output paths must be different');
    end
    if ~isfile(inputPath)
        error('run_batch:noInput', 'Input CSV not found: %s', inputPath);
    end

    data = readtable(inputPath, 'Encoding', 'UTF-8', 'VariableNamingRule', 'preserve');
    names = data.Properties.VariableNames;

    required = required_columns();
    missing  = required(~ismember(required, names));
    if ~isempty(missing)
        error('run_batch:missingColumns', 'Missing required CSV columns: %s', strjoin(missing, ', '));
    end
    if height(data) == 0
        error('run_batch:empty', 'Input CSV contains no parameter rows');
    end

    if ~ismember('case_id', names)
        ids = arrayfun(@(i) sprintf('case_%06d', i), 1:height(data), 'UniformOutput', false)';
        data = addvars(data, ids, 'Before', 1, 'NewVariableNames', 'case_id');
    end

    nRows   = height(data);
    rows    = table2struct(data);
    results = cell(nRows, 1);

    for idx = 1:nRows
        try
            results{idx} = calculate_case(rows(idx), options);
        catch err
            error('run_batch:caseFailed', 'Case %s (CSV row %d): %s', ...
                  case_id_text(data, idx), idx + 1, err.message);
        end
    end

    % 列顺序取第一个结果的字段顺序（所有行结构一致）
    fields = fieldnames(results{1});
    nCols  = numel(fields);

    out = cell(nRows + 1, nCols);
    for c = 1:nCols
        out{1, c} = field_to_header(fields{c});
    end
    for r = 1:nRows
        s = results{r};
        for c = 1:nCols
            out{r + 1, c} = s.(fields{c});
        end
    end

    write_csv_utf8bom(out, outputPath);

    count = nRows;
end


% ---------------------------------------------------------------- 本地辅助
function p = canonical_path(p)
    p = char(p);
    [d, n, e] = fileparts(p);
    if isempty(d)
        d = pwd;
    end
    if isfolder(d)
        try
            d = char(java.io.File(d).getCanonicalPath());
        catch
            % 保底：拿不到规范路径就用原值
        end
    end
    p = fullfile(d, [n e]);
end

function t = case_id_text(data, idx)
    v = data.case_id(idx);
    if iscell(v)
        v = v{1};
    end
    t = char(string(v));
end
