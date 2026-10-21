function write_csv_utf8bom(C, path)
%WRITE_CSV_UTF8BOM  写 UTF-8（带 BOM）的 CSV
%   C 为 cell 矩阵，第一行是列名。列名可以包含 '-' 等 MATLAB 变量名不允许的字符。
%
%   带 BOM 是为了让中文 Windows 的 Excel 双击打开不乱码，
%   与 Python 的 encoding='utf-8-sig' 一致。
%   浮点用 %.17g 输出，保证读回来与原 double 逐位相同。

    fid = fopen(path, 'w', 'n', 'UTF-8');
    if fid < 0
        error('write_csv_utf8bom:cannotWrite', 'Cannot write file: %s', path);
    end
    cleanup = onCleanup(@() fclose(fid));   %#ok<NASGU>

    fwrite(fid, uint8([239 187 191]), 'uint8');   % EF BB BF

    [nR, nC] = size(C);
    for r = 1:nR
        parts = cell(1, nC);
        for c = 1:nC
            parts{c} = format_value(C{r, c});
        end
        fprintf(fid, '%s\n', strjoin(parts, ','));
    end
end


function s = format_value(v)
    if ischar(v)
        s = v;
    elseif isstring(v)
        s = char(v);
    elseif isempty(v)
        s = '';
    elseif islogical(v) && isscalar(v)
        s = sprintf('%d', v);
    elseif isnumeric(v) && isscalar(v)
        if isfinite(v)
            s = sprintf('%.17g', v);
        else
            s = 'NaN';
        end
    else
        s = char(string(v));
    end
    % CSV 里的逗号 / 引号 / 换行做最小转义
    if contains(s, ',') || contains(s, '"') || contains(s, newline)
        s = ['"' strrep(s, '"', '""') '"'];
    end
end
